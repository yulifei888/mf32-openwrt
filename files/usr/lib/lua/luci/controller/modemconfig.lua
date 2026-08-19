module("luci.controller.modemconfig", package.seeall)

function index()
    -- 收紧 acl：原为 acl_depends={"unauthenticated"}（免登录可改频段），
    -- 改为 app 自身角色 luci-app-mmconfig（已认证用户可用，匿名不可见）
    local page = entry({"admin", "modem", "modemconfig"}, cbi("modem/modemconfig"), _("ModemConfig"), 60)
    page.acl_depends = { "luci-app-mmconfig" }

    entry({"admin", "modem", "modemconfig", "getmode"}, call("getmode"))
    entry({"admin", "modem", "modemconfig", "modemconfig"}, call("modemconfig"))
end

function getmode()
    local util = require "luci.util"
    local mmcli = util.exec("mmcli -m any 2>/dev/null")
    luci.http.prepare_content("application/json")
    luci.http.write_json({ output = mmcli })
end

function modemconfig()
    local util = require "luci.util"
    util.exec("/usr/bin/modemconfig >/dev/null 2>&1")
    luci.http.redirect(luci.dispatcher.build_url("admin", "modem", "modemconfig"))
end
