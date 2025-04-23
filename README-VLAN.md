# VLAN Support Components

This document describes the components added to support advanced VLAN functionality and improve OLT compatibility in the firmware.

## Overview

The VLAN support components provide:
- Improved handling of standard and multicast VLAN tags
- Better compatibility with various OLT vendors
- A web interface for monitoring and configuring VLAN settings
- Automatic fixing of VLAN configuration issues

## Components

### Scripts

1. **vlan-svc.sh** (`/etc/init.d/vlan-svc.sh`)
   - Init script that starts the VLAN service
   - Controlled by UCI configuration (8311.config.vlan_svc)

2. **vlanexec.sh** (`/opt/lantiq/bin/vlanexec.sh`)
   - Main VLAN execution engine
   - Handles specialized VLAN tagging operations
   - Monitors ONU state and applies VLAN configuration

3. **8311-vlans-lib.sh** (`/lib/8311/8311-vlans-lib.sh`)
   - Library of VLAN utility functions
   - Provides TC (traffic control) flower filter operations

4. **8311-fix-vlans.sh** (`/usr/sbin/8311-fix-vlans.sh`)
   - Automatically fixes VLAN configuration to improve compatibility
   - Handles upstream and downstream VLAN mappings

5. **8311-detect-config.sh** (`/usr/sbin/8311-detect-config.sh`)
   - Detects current VLAN configuration
   - Creates configuration file with appropriate settings

6. **8311-extvlan-decode.sh** (`/usr/sbin/8311-extvlan-decode.sh`)
   - Decodes extended VLAN configuration from the OLT
   - Provides information for the web interface

### LuCI Web Interface

1. **VLAN Tables** (`/usr/lib/lua/luci/view/8311/vlans.htm`)
   - Web interface for viewing VLAN configuration
   - Allows adjusting multicast VLAN settings

2. **Controller** (`/usr/lib/lua/luci/controller/8311.lua`)
   - Provides web interface routes and actions

3. **Configuration Model** (`/usr/lib/lua/luci/model/cbi/8311-config.lua`)
   - UCI configuration interface for VLAN settings

## Configuration Options

The following UCI options are available under `8311.config`:

- **vlan_svc**: Enable/disable VLAN service (0/1)
- **fix_vlans**: Enable/disable automatic VLAN fixing (0/1)
- **internet_vlan**: VLAN ID for Internet service (0-4095, 0 = untagged)
- **services_vlan**: VLAN ID for services like IPTV (1-4095)
- **us_vlan_id**: Upstream VLAN ID (1-4095)
- **n_to_1_vlan**: Enable N:1 VLAN mode (0/1)
- **ds_mc_tci**: Downstream multicast Tag Control Information
- **us_mc_vid**: Upstream multicast VLAN ID (1-4095)

## Usage

1. Access the web interface at: Admin → 8311 Customization → VLAN Tables
2. Enable VLAN service in the configuration section
3. Configure appropriate VLAN IDs based on your ISP requirements
4. Enable automatic VLAN fixing if needed

## Troubleshooting

If experiencing issues with VLAN connectivity:

1. Check system logs: `logread | grep vlan`
2. View VLAN configuration: `/usr/sbin/8311-extvlan-decode.sh -t`
3. Restart the VLAN service: `/etc/init.d/vlan-svc restart` 