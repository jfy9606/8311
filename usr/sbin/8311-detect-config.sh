#!/bin/sh

log() {
    logger -t 8311-detect-config "$@"
}

debug() {
    while read -r line; do
        log "$line"
    done
}

usage() {
    cat <<EOF >&2
Usage: $0 [option]
Options:
  -c <file>    Create config file
  -H           Display state hash
  -h           Show this help
EOF
    exit 1
}

# Default values
CONFIG_FILE=
SHOW_HASH=0

while getopts "c:Hh" opt; do
    case $opt in
        c) CONFIG_FILE="$OPTARG" ;;
        H) SHOW_HASH=1 ;;
        h) usage ;;
        *) usage ;;
    esac
done

# Find TC program
TC=$(PATH=/usr/sbin:/sbin /usr/bin/which tc)

# Get TC rules state hash
TC_STATE=$($TC -s filter show dev eth0_0 &>/dev/null)$($TC -s filter show dev eth0_0_2 &>/dev/null)
STATE_HASH=$(echo "$TC_STATE" | md5sum | cut -d' ' -f1)

if [ "$SHOW_HASH" -eq 1 ]; then
    echo "$STATE_HASH"
    exit 0
fi

if [ -z "$CONFIG_FILE" ]; then
    echo "No config file specified." >&2
    usage
fi

# Create initial config file
echo "# Enable fix_vlans script?" > "$CONFIG_FILE"
echo "FIX_ENABLED=1" >> "$CONFIG_FILE"
echo "STATE_HASH=$STATE_HASH" >> "$CONFIG_FILE"

# Get unicast VLAN
echo "# Unicast VLAN ID from ISP side" >> "$CONFIG_FILE"
echo "UNICAST_VLAN=35" >> "$CONFIG_FILE"

# Set up Internet VLAN and PMAP
echo "# Internet physical mapping" >> "$CONFIG_FILE"
echo "INTERNET_PMAP=eth0_1" >> "$CONFIG_FILE"

# Set up Internet VLAN configuration
echo "# Internet VLAN exposed to network (0 = untagged)." >> "$CONFIG_FILE"
echo "INTERNET_VLAN=0" >> "$CONFIG_FILE"
echo "# Services VLAN exposed to network." >> "$CONFIG_FILE"
echo "SERVICES_VLAN=36" >> "$CONFIG_FILE"

# Services PMAP (if applicable)
echo "# Services physical mapping (empty to disable)" >> "$CONFIG_FILE"
echo "SERVICES_PMAP=eth0_2" >> "$CONFIG_FILE"

# Multicast GEM for IPTV
echo "# Multicast GEM for IPTV (empty to disable)" >> "$CONFIG_FILE"
echo "MULTICAST_GEM=eth0_0_2" >> "$CONFIG_FILE"

log "Created config file at $CONFIG_FILE"
exit 0 