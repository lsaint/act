package.path = "./script/?.lua;" .. package.path
package.path = "./db/?.lua;" .. package.path
package.path = "./script/lib/?.lua;" .. package.path
package.cpath = "./script/lib/?.so;" .. package.cpath

protobuf = require "protobuf"
parser = require "parser"

watchdog = require "watchdog"

require "timer"
require "uri"
require "db"

parser.register("client.proto", "./proto/")

function dispatch(sid, uid, pname, data)
    watchdog.dispatch(sid, uid, pname, data)
end

function SendMsg(pname, msg, uids, sid)
    local p = string.format("%s%s", "proto.", pname)
    local _msg = protobuf.encode(p, msg)
    local uri = URI[p]
    --print("LuaSendMsg", pname, uids[1], sid)
    GoSendMsg(uri, _msg, sid, uids)
end

function update()
    TimerUpdate()
end

function giftCb(op, sid, uid, touid, giftid, giftcout, orderid)
    watchdog.giftCb(op, sid, uid, touid, giftid, giftcout, orderid)
end

