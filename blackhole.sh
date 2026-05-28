#!/bin/bash
#
# blackhole.sh - Add blackhole routes to all Sophos XG firewalls via XML API
# Usage: op run --env-file=.env -- ./blackhole.sh
#

set -euo pipefail

BLACKHOLE_FILE="blackhole.txt"

# Define firewall names (must match env var prefixes)
FIREWALLS=("FREJA" "ODENSE")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if blackhole file exists
if [[ ! -f "${BLACKHOLE_FILE}" ]]; then
    echo -e "${RED}Error: ${BLACKHOLE_FILE} not found${NC}"
    exit 1
fi

# Convert CIDR prefix length to dotted subnet mask
cidr_to_mask() {
    local cidr=$1
    local mask=""
    local full_octets=$((cidr / 8))
    local partial_bits=$((cidr % 8))

    for ((i=0; i<4; i++)); do
        if (( i < full_octets )); then
            mask+="255"
        elif (( i == full_octets )); then
            mask+="$(( 256 - (1 << (8 - partial_bits)) ))"
        else
            mask+="0"
        fi
        (( i < 3 )) && mask+="."
    done
    echo "${mask}"
}

# Function to add a blackhole route on a single firewall
add_blackhole_route() {
    local fw_name="$1"
    local dest_ip="$2"
    local netmask="$3"
    local host_var="SOPHOS_${fw_name}_HOST"
    local user_var="SOPHOS_${fw_name}_USERNAME"
    local pass_var="SOPHOS_${fw_name}_PASSWORD"

    local host="${!host_var:-}"
    local username="${!user_var:-}"
    local password="${!pass_var:-}"

    if [[ -z "${host}" || -z "${username}" || -z "${password}" ]]; then
        echo -e "  ${YELLOW}[SKIP]${NC} ${fw_name} - missing credentials"
        return 0
    fi

    local api_url="https://${host}:4444/webconsole/APIController"

    local payload="<Request>
    <Login>
        <Username>${username}</Username>
        <Password>${password}</Password>
    </Login>
    <Set operation=\"add\">
        <UnicastRoute>
            <IPFamily>IPv4</IPFamily>
            <DestinationIP>${dest_ip}</DestinationIP>
            <Netmask>${netmask}</Netmask>
            <Interface>Blackhole</Interface>
            <Blackhole>Enable</Blackhole>
            <Distance>0</Distance>
            <AdministrativeDistance>1</AdministrativeDistance>
            <Status>ON</Status>
            <Description>Blackhole route added via API</Description>
        </UnicastRoute>
    </Set>
</Request>"

    local response
    response=$(curl -s -k -X POST "${api_url}" -d "reqxml=${payload}" 2>&1)

    if echo "${response}" | grep -q "200"; then
        echo -e "  ${GREEN}[OK]${NC} ${fw_name} - ${dest_ip}/${netmask}"
    elif echo "${response}" | grep -q "Authentication Successful"; then
        local status_msg
        status_msg=$(echo "${response}" | grep -oP '(?<=<Status code=")[^"]+' | tail -1)
        local status_text
        status_text=$(echo "${response}" | grep -oP '(?<=<Status code="[0-9]{3}">)[^<]+' | tail -1)
        echo -e "  ${RED}[FAIL]${NC} ${fw_name} - ${dest_ip}/${netmask} (code: ${status_msg})"
        echo "        ${status_text}"
    else
        echo -e "  ${RED}[FAIL]${NC} ${fw_name} - ${dest_ip}/${netmask}"
        echo "        ${response}"
    fi
}

# Main loop
echo "=== Adding Blackhole Routes ==="
echo ""

while IFS= read -r line; do
    # Skip empty lines and comments
    [[ -z "${line}" || "${line}" == \#* ]] && continue

    network=$(echo "${line}" | tr -d ' ')

    # Parse IP and CIDR
    if [[ "${network}" == *"/"* ]]; then
        dest_ip=$(echo "${network}" | cut -d'/' -f1)
        cidr=$(echo "${network}" | cut -d'/' -f2)
    else
        dest_ip="${network}"
        cidr="32"
    fi

    netmask=$(cidr_to_mask "${cidr}")

    echo "Route: ${dest_ip}/${cidr} (${netmask})"

    for fw in "${FIREWALLS[@]}"; do
        add_blackhole_route "${fw}" "${dest_ip}" "${netmask}"
    done

    echo ""
done < "${BLACKHOLE_FILE}"

echo "=== Done ==="
