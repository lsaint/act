package.path = "/Users/lsaint/Documents/SRC/pbc/binding/lua/?.lua;" .. package.path
package.path = "/Users/lsaint/go/src/act/script/?.lua;" .. package.path
package.cpath = "/Users/lsaint/Documents/SRC/pbc/binding/lua/?.so;" .. package.cpath

protobuf = require "protobuf"
parser = require "parser"

watchdog = require "watchdog"

require "timer"
require "json"
require "uri"

parser.register("client.proto", "/home/lsaint/go/src/act/proto/")

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

