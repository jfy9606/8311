module("luci.controller.8311", package.seeall)

local util = require "luci.util"
local fs = require "nixio.fs"
local ltemplate = require "luci.template"
local translate = require "luci.i18n".translate

function index()
    entry({"admin", "8311"}, firstchild(), translate("8311 Customization"), 60)
    entry({"admin", "8311", "status"}, call("action_status"), translate("Status"), 1)
    entry({"admin", "8311", "config"}, cbi("8311-config"), translate("Configuration"), 2)
    entry({"admin", "8311", "diag"}, cbi("8311-diag"), translate("Diagnostics"), 3)
    entry({"admin", "8311", "vlans"}, call("action_vlans"), translate("VLAN Tables"), 4)
    
    entry({"admin", "8311", "vlans", "extvlans"}, call("action_vlan_extvlans"))
end

function action_status()
    ltemplate.render("8311/status", {})
end

function action_vlans()
    ltemplate.render("8311/vlans", {})
end

function action_vlan_extvlans()
    local vlans_tables = util.exec("/usr/sbin/8311-extvlan-decode.sh")
    
    if luci.sys.process.exec({"/usr/sbin/8311-extvlan-decode.sh", "-t"}, luci.http.write, luci.http.write).code == 0 then
        return
    else
        luci.sys.process.exec({"/usr/sbin/8311-extvlan-decode.sh"}, luci.http.write, luci.http.write)
    end
end 