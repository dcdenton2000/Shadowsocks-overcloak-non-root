#!/bin/bash

# Ensure the script is run with sudo or as root, but will create a non-root user
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run with sudo" 
   exit 1
fi

# Create a non-root system user for running the services
SERVICE_USER="shadowsocks"
useradd -r -s /bin/false $SERVICE_USER

# Predefined list of websites for Cloak plugin
WEBSITES=(
    "www.microsoft.com"
    "www.cloudflare.com"
    "www.github.com"
    "www.wikipedia.org"
    "www.apache.org"
)

# Function to let user choose websites
select_websites() {
    echo "Select 5 websites for Cloak plugin (enter numbers, space-separated):"
    for i in "${!WEBSITES[@]}"; do
        echo "$((i+1)). ${WEBSITES[i]}"
    done
    
    read -p "Enter your choices (1-5): " -a SELECTED_INDICES
    
    SELECTED_WEBSITES=()
    for index in "${SELECTED_INDICES[@]}"; do
        if [[ $index -ge 1 && $index -le ${#WEBSITES[@]} ]]; then
            SELECTED_WEBSITES+=("${WEBSITES[$((index-1))]}")
        fi
    done
    
    if [[ ${#SELECTED_WEBSITES[@]} -ne 5 ]]; then
        echo "You must select exactly 5 websites. Exiting."
        exit 1
    fi
}

# Call the website selection function
select_websites

# Rest of the script remains similar, with modifications for non-root and encryption

# Update the Cloak configuration to use encryption and selected websites
cat <<EOF > /etc/cloak/config.json
{
    "ProxyBook": {
        "shadowsocks": ["tcp", "127.0.0.1:8388"]
    },
    "BindAddr": [":443"],
    "BypassUID": [],
    "RedirAddrs": [
        "${SELECTED_WEBSITES[0]}",
        "${SELECTED_WEBSITES[1]}",
        "${SELECTED_WEBSITES[2]}",
        "${SELECTED_WEBSITES[3]}",
        "${SELECTED_WEBSITES[4]}"
    ],
    "PrivateKey": "$PRIVATE_KEY",
    "AdminUID": "$ADMIN_UID",
    "DatabasePath": "/etc/cloak/userinfo.db",
    "EncryptionMethod": "aes-256-gcm"  # Added encryption method
}
EOF

# Modify the Cloak service to run as non-root user
cat <<EOF > /etc/systemd/system/cloak.service
[Unit]
Description=Cloak Server
After=network.target

[Service]
User=$SERVICE_USER
Group=$SERVICE_USER
AmbientCapabilities=CAP_NET_BIND_SERVICE
ExecStart=/usr/local/bin/ck-server -c /etc/cloak/config.json
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Update Cloak plugin parameters with encryption
CLOAK_PLUGIN="ck-client;UID=$ADMIN_UID;ProxyMethod=shadowsocks;PublicKey=$PUBLIC_KEY;EncryptionMethod=aes-256-gcm;ServerName=${SELECTED_WEBSITES[0]}"
CLOAK_PLUGIN_URLENCODED=$(echo -n "$CLOAK_PLUGIN" | jq -sRr @uri)

# Ensure proper permissions
chown -R $SERVICE_USER:$SERVICE_USER /etc/cloak
chmod 750 /etc/cloak
chmod 640 /etc/cloak/config.json

# The rest of the script remains largely the same, 
# but ensure services are started with the non-root user
