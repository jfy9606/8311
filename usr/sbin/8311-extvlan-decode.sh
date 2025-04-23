#!/bin/sh

# omci pipe command
OMCI_PIPE="/opt/lantiq/bin/omci_pipe.sh"

# Default output format
TEXT_OUTPUT=0

# Process arguments
while [ $# -gt 0 ]; do
    case "$1" in
        -t) TEXT_OUTPUT=1 ;;
        -h|--help)
            echo "Usage: $0 [-t]"
            echo "  -t    Output in text format instead of HTML"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
    shift
done

# Function to detect extended VLAN configuration
detect_ext_vlan() {
    # Get ME171 (Extended VLAN Tagging Operation Configuration Data) instances
    me171_instances=$($OMCI_PIPE mib_dump 2>/dev/null | grep "Extended VLAN conf data" | sed -n 's/\(0x\)/\1/p' | cut -f 3 -d '|' | cut -f 1 -d '(' | head -n 1 | sed s/[[:space:]]//g)

    # Check for multicast VLANs (ME130)
    me130_instances=$($OMCI_PIPE mib_dump 2>/dev/null | grep "Multicast operations profile" | sed -n 's/\(0x\)/\1/p' | cut -f 3 -d '|' | cut -f 1 -d '(' | head -n 1 | sed s/[[:space:]]//g)

    if [ -z "$me171_instances" ]; then
        echo "No Extended VLAN configuration detected."
        return 1
    fi

    # Process ME171 instances
    for instance in $me171_instances; do
        # Get associated ME pointer
        associated_me=$($OMCI_PIPE managed_entity_attr_data_get 171 "$instance" 7 | grep "attr_data" | cut -d= -f2 | tr -d ' ')
        
        # Get input/output TPID
        input_tpid=$($OMCI_PIPE managed_entity_attr_data_get 171 "$instance" 1 | grep "attr_data" | cut -d= -f2 | tr -d ' ')
        output_tpid=$($OMCI_PIPE managed_entity_attr_data_get 171 "$instance" 2 | grep "attr_data" | cut -d= -f2 | tr -d ' ')
        
        # Get downstream mode
        ds_mode=$($OMCI_PIPE managed_entity_attr_data_get 171 "$instance" 3 | grep "attr_data" | cut -d= -f2 | tr -d ' ')
        
        # Get received frame VLAN tagging operation table
        rx_table=$($OMCI_PIPE managed_entity_attr_data_get 171 "$instance" 5 | grep "attr_data" | cut -d= -f2 | tr -d ' ')
        
        # Get sent frame VLAN tagging operation table
        tx_table=$($OMCI_PIPE managed_entity_attr_data_get 171 "$instance" 6 | grep "attr_data" | cut -d= -f2 | tr -d ' ')

        # Output information
        if [ "$TEXT_OUTPUT" -eq 1 ]; then
            echo "Extended VLAN Configuration - Instance: $instance"
            echo "Associated ME: $associated_me"
            echo "Input TPID: $input_tpid"
            echo "Output TPID: $output_tpid"
            echo "Downstream Mode: $ds_mode"
            echo "RX VLAN Tagging Table: $rx_table"
            echo "TX VLAN Tagging Table: $tx_table"
            echo "----------------------------------------"
        else
            echo "<div class='vlan-config'>"
            echo "<h3>Extended VLAN Configuration - Instance: $instance</h3>"
            echo "<p><strong>Associated ME:</strong> $associated_me</p>"
            echo "<p><strong>Input TPID:</strong> $input_tpid</p>"
            echo "<p><strong>Output TPID:</strong> $output_tpid</p>"
            echo "<p><strong>Downstream Mode:</strong> $ds_mode</p>"
            echo "<p><strong>RX VLAN Tagging Table:</strong> $rx_table</p>"
            echo "<p><strong>TX VLAN Tagging Table:</strong> $tx_table</p>"
            echo "</div>"
        fi
    done

    # Process multicast VLANs if available
    if [ -n "$me130_instances" ]; then
        for instance in $me130_instances; do
            table_entries=$($OMCI_PIPE managed_entity_attr_data_get 130 "$instance" 1 | grep "attr_data" | cut -d= -f2 | tr -d ' ')
            
            if [ "$TEXT_OUTPUT" -eq 1 ]; then
                echo "Multicast VLAN Configuration - Instance: $instance"
                echo "Table Entries: $table_entries"
                echo "----------------------------------------"
            else
                echo "<div class='vlan-config'>"
                echo "<h3>Multicast VLAN Configuration - Instance: $instance</h3>"
                echo "<p><strong>Table Entries:</strong> $table_entries</p>"
                echo "</div>"
            fi
        done
    fi

    return 0
}

# Main execution
if [ "$TEXT_OUTPUT" -eq 1 ]; then
    echo "===== Extended VLAN Configuration ====="
    detect_ext_vlan
else
    echo "<html><head><title>Extended VLAN Configuration</title>"
    echo "<style>"
    echo ".vlan-config { margin-bottom: 20px; border: 1px solid #ccc; padding: 10px; }"
    echo "h3 { margin-top: 0; color: #333; }"
    echo "</style></head><body>"
    echo "<h2>Extended VLAN Configuration</h2>"
    detect_ext_vlan
    echo "</body></html>"
fi 