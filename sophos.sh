#!/bin/bash

# Sophos Firewall API Credentials
SOPHOS_API_URL="https://<firewall-ip>/webconsole/APIController"
SOPHOS_API_USERNAME="apiuser"
SOPHOS_API_PASSWORD="yourpassword"
CSV_FILE="ip.csv"
HOST_GROUP_NAME="MS Graph Notifications"
NAME_PREFIX="MSGraph_"

# Function to get subnet mask from CIDR
get_subnet_mask() {
    local cidr=$1
    local mask
    case ${cidr} in
        32) mask="255.255.255.255" ;;
        31) mask="255.255.255.254" ;;
        30) mask="255.255.255.252" ;;
        29) mask="255.255.255.248" ;;
        28) mask="255.255.255.240" ;;
        27) mask="255.255.255.224" ;;
        26) mask="255.255.255.192" ;;
        25) mask="255.255.255.128" ;;
        24) mask="255.255.255.0" ;;
        23) mask="255.255.254.0" ;;
        22) mask="255.255.252.0" ;;
        21) mask="255.255.248.0" ;;
        20) mask="255.255.240.0" ;;
        19) mask="255.255.224.0" ;;
        18) mask="255.255.192.0" ;;
        17) mask="255.255.128.0" ;;
        16) mask="255.255.0.0" ;;
        15) mask="255.254.0.0" ;;
        14) mask="255.252.0.0" ;;
        13) mask="255.248.0.0" ;;
        12) mask="255.240.0.0" ;;
        11) mask="255.224.0.0" ;;
        10) mask="255.192.0.0" ;;
        9) mask="255.128.0.0" ;;
        8) mask="255.0.0.0" ;;
        *) mask="255.255.255.255" ;; # Default to single IP if no valid CIDR
    esac
    echo "${mask}"
}

# Read the CSV file and process each line
while IFS=, read -r ip; do
    ip_trimmed=$(echo "${ip}" | tr -d ' ')
    if [[ "{$ip_trimmed}" == *"/"* ]]; then
        ip_address=$(echo "${ip_trimmed}" | cut -d'/' -f1)
        cidr=$(echo "${ip_trimmed}" | cut -d'/' -f2)
        subnet_mask="$(get_subnet_mask "${cidr}")"
        host_type="Network"
        name_tag="${NAME_PREFIX}${ip_trimmed}"  # Use CIDR notation in Name tag for networks
    else
        ip_address="${ip_trimmed}"
        subnet_mask="255.255.255.255"
        host_type="IP"
        name_tag="${NAME_PREFIX}${ip_address}"  # Use IP only in Name tag for single IPs
    fi

    #echo "DEBUG: Processing $host_type - Name: $name_tag, IP: $ip_address, Subnet: $subnet_mask"

    payload="<?xml version=\"1.0\" encoding=\"UTF-8\"?>
    <Request>
        <Login>
            <Username>${SOPHOS_API_USERNAME}</Username>
            <Password>${SOPHOS_API_PASSWORD}</Password>
        </Login>
        <Set>
            <IPHost>
                <Name>${name_tag}</Name>
                <IPFamily>IPv4</IPFamily>
                <HostType>${host_type}</HostType>
                <IPAddress>${ip_address}</IPAddress>
                <Subnet>${subnet_mask}</Subnet>
                <HostGroupList>
                    <HostGroup>${HOST_GROUP_NAME}</HostGroup>
                </HostGroupList>
            </IPHost>
        </Set>
    </Request>"

    #echo "DEBUG: Sending payload:\n${payload}"
    
    response=$(curl -s -k -X POST "${SOPHOS_API_URL}" -d "reqxml=${payload}")
    
    #echo "DEBUG: Response:\n${response}"

done < "${CSV_FILE}"

