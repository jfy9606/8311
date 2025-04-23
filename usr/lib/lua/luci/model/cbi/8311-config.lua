local m, s

local fs = require "nixio.fs"
local sys = require "luci.sys"
local util = require "luci.util"
local http = require "luci.http"
local nixio = require "nixio"
local translate = require "luci.i18n".translate

m = Map("8311", translate("8311 Configuration"),
    translate("This section allows configuration of 8311-specific features."))

-- Create config section if it doesn't exist
m.uci:foreach("8311", "config", function(s) exists = true end)
if not exists then
    m.uci:section("8311", "config", nil, {})
end

config = m:section(TypedSection, "config", translate("Configuration"))
config.anonymous = true
config:tab("general", translate("General"))
config:tab("vlan", translate("VLAN"))

-- General Tab Settings
-- General settings would go here

-- VLAN Tab Settings
local vlan_svc =
config:taboption("vlan", Flag, "vlan_svc", translate("Enable VLAN Tagging Service"),
    translate("Allows for customization of the VLAN Tagging Operations between the " ..
    "ONU and OLT."))
vlan_svc.rmempty = false

local fix_vlans = config:taboption("vlan", Flag, "fix_vlans", translate("Auto-Fix VLANs"),
    translate("Automatically fix VLAN configuration to improve compatibility with OLT."))
fix_vlans.rmempty = false

local internet_vlan = 
config:taboption("vlan", Value, "internet_vlan", translate("Internet VLAN"),
    translate("VLAN ID for Internet service (0-4095, 0 for untagged)"))
internet_vlan.datatype = "range(0,4095)"
internet_vlan.default = "0"

local services_vlan =
config:taboption("vlan", Value, "services_vlan", translate("Services VLAN"),
    translate("VLAN ID for services like IPTV and VoIP (1-4095)"))
services_vlan.datatype = "range(1,4095)"
services_vlan.default = "36"

local us_vlan_id =
config:taboption("vlan", Value, "us_vlan_id", translate("Upstream VLAN ID"),
    translate("VLAN ID for upstream traffic (1-4095)"))
us_vlan_id.datatype = "range(1,4095)"
us_vlan_id.default = "35"

local n_to_1_vlan =
config:taboption("vlan", Flag, "n_to_1_vlan", translate("N:1 VLAN Mode"),
    translate("Enable N:1 VLAN mode for better OLT compatibility"))
n_to_1_vlan.rmempty = false

local ds_mc_tci =
config:taboption("vlan", Value, "ds_mc_tci", translate("Downstream Multicast TCI"),
    translate("Tag Control Information for downstream multicast traffic"))
ds_mc_tci.default = "8100"

local us_mc_vid =
config:taboption("vlan", Value, "us_mc_vid", translate("Upstream Multicast VLAN ID"),
    translate("VLAN ID for upstream multicast traffic (1-4095)"))
us_mc_vid.datatype = "range(1,4095)"
us_mc_vid.default = "36"

return m 