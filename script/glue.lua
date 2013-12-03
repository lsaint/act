package.path = "./conf/?.txt;" .. package.path
package.path = "./script/?.lua;" .. package.path
package.path = "./db/?.lua;" .. package.path
package.path = "./script/lib/?.lua;" .. package.path
package.cpath = "./script/lib/?.so;" .. package.cpath

io.stdout:setvbuf("line")

protobuf = require "protobuf"
parser = require "parser"

watchdog = require "watchdog"

require "config"
require "timer"
require "uri"
require "db"

parser.register("client.proto", "./proto/")

function dispatch(tsid, sid, uid, pname, data)
    watchdog.dispatch(tsid, sid, uid, pname, data)
end

function SendMsg(pname, msg, uids, tsid, sid)
    local p = string.format("%s%s", "proto.", pname)
    local _msg = protobuf.encode(p, msg)
    local uri = URI[p]
    GoSendMsg(uri, _msg, tsid, sid, uids)
end

function update()
    TimerUpdate()
end

function giftCb(op, sid, uid, touid, giftid, giftcout, orderid)
    watchdog.giftCb(op, sid, uid, touid, giftid, giftcout, orderid)
end

function netCtrl(s)
    watchdog.netCtrl(s)
end

----- POST
local post_sn = 1
local post_callbacks = {} -- sn = cb
function GoPostAsync(url, s, func)
    local sn = post_sn
    post_sn = post_sn + 1
    goPostAsync(url, s, sn)
    if func then
        post_callbacks[sn] = func
    end
end

function postDone(sn, ret)
    local cb = post_callbacks[sn]
    if cb then
        cb(ret)
        post_callbacks[sn] = cb
    end
end
