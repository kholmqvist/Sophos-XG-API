#!/bin/bash
#
# blackhole.sh - Add blackhole routes to all Sophos XG firewalls via REST API (v19+)
# Usage: op run --env-file=.env -- ./blackhole.sh
#

set -euo pipefail

BLACKHOLE_FILE="${1:-blackhole.txt}"

# Define firewall names (must match env var prefixes)
FIREWALLS=("FREJA" "ODENSE" "FIREWALLIN" "FIREWALLTH" "FIREWALLUK" "UNWIND1")

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

trim() {
    local value="$1"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    echo "${value}"
}

is_valid_ipv4() {
    local ip="$1"
    local octet
    local -a octets

    [[ "${ip}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1

    IFS='.' read -r -a octets <<< "${ip}"
    for octet in "${octets[@]}"; do
        [[ "${octet}" =~ ^[0-9]+$ ]] || return 1
        (( octet >= 0 && octet <= 255 )) || return 1
    done
}

normalize_network() {
    local raw="$1"
    local ip
    local cidr

    raw="${raw%%#*}"
    raw="$(trim "${raw}")"
    raw="${raw//[[:space:]]/}"

    [[ -n "${raw}" ]] || return 1

    if [[ "${raw}" == */* ]]; then
        ip="${raw%/*}"
        cidr="${raw#*/}"
    else
        ip="${raw}"
        cidr="32"
    fi

    is_valid_ipv4 "${ip}" || return 1
    [[ "${cidr}" =~ ^[0-9]+$ ]] || return 1
    (( cidr >= 0 && cidr <= 32 )) || return 1

    echo "${ip}/${cidr}"
}

# Function to add a blackhole route on a single firewall
add_blackhole_route() {
    local fw_name="$1"
    local network="$2"
    local host_var="SOPHOS_${fw_name}_HOST"
    local key_var="SOPHOS_${fw_name}_API_KEY"

    local host="${!host_var:-}"
    local api_key="${!key_var:-}"

    if [[ -z "${host}" || -z "${api_key}" ]]; then
        echo -e "  ${YELLOW}[SKIP]${NC} ${fw_name} - missing credentials"
        return 0
    fi

    local route_name="blackhole-${network//\//-}"
    local api_url="https://${host}:4444/api/v2/static_route"

    local payload
    payload=$(cat <<EOF
{
    "name": "${route_name}",
    "destination_network": "${network}",
    "gateway_type": "blackhole",
    "admin_status": "enable"
}
EOF
    )

    local response
    if ! response=$(curl -s -k -w "\n%{http_code}" -X POST "${api_url}" \
        -H "Authorization: Bearer ${api_key}" \
        -H "Content-Type: application/json" \
        -d "${payload}" 2>&1); then
        echo -e "  ${RED}[FAIL]${NC} ${fw_name} - ${network} (curl error)"
        echo "        ${response}"
        return 0
    fi

    local http_code
    http_code=$(echo "${response}" | tail -1)
    local body
    body=$(echo "${response}" | sed '$d')

    if [[ "${http_code}" == "2"* ]]; then
        echo -e "  ${GREEN}[OK]${NC} ${fw_name} - ${network}"
    else
        echo -e "  ${RED}[FAIL]${NC} ${fw_name} - ${network} (HTTP ${http_code})"
        echo "        ${body}"
    fi
}

# Main loop
echo "=== Adding Blackhole Routes ==="
echo "Source: ${BLACKHOLE_FILE}"
echo ""

processed=0
invalid=0

while IFS= read -r line; do
    if ! network="$(normalize_network "${line}")"; then
        stripped="$(trim "${line%%#*}")"
        if [[ -n "${stripped}" ]]; then
            echo -e "${YELLOW}[WARN]${NC} Skipping invalid entry: ${line}"
            ((invalid+=1))
        fi
        continue
    fi

    ((processed+=1))
    echo "Network: ${network}"

    for fw in "${FIREWALLS[@]}"; do
        add_blackhole_route "${fw}" "${network}" || true
    done

    echo ""
done < "${BLACKHOLE_FILE}"

if (( processed == 0 )); then
    echo -e "${YELLOW}No blackhole routes found in ${BLACKHOLE_FILE}.${NC}"
fi

if (( invalid > 0 )); then
    echo -e "${YELLOW}Skipped ${invalid} invalid entr$( (( invalid == 1 )) && echo "y" || echo "ies" ).${NC}"
fi

echo "=== Done ==="
