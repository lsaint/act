package.path = "/Users/lsaint/Documents/SRC/pbc/binding/lua/?.lua;" .. package.path
package.path = "/Users/lsaint/go/src/act/script/?.lua;" .. package.path
package.path = "/Users/lsaint/go/src/act/db/?.lua;" .. package.path
package.cpath = "/Users/lsaint/Documents/SRC/pbc/binding/lua/?.so;" .. package.cpath

protobuf = require "protobuf"
parser = require "parser"

watchdog = require "watchdog"

require "timer"
require "json"
require "uri"
require "db"

parser.register("client.proto", "/home/lsaint/go/src/act/proto/")

function dispatch(sid, uid, pname, data)
    watchdog.dispatch(sid, uid, pname, data)

    --SendMsg("proto.S2CLoginRep", rep, {req.uid}, 0)
    --Broadcast("proto.S2CLoginRep", rep,  1640285)

    --ret = GoPost(json.encode({first='mars',second='venus',third='earth'} ))
    --print("GoPost:", ret)
end

function SendMsg(pname, msg, uids, sid)
    p = string.format("%s%s", "proto.", pname)
    _msg = protobuf.encode(p, msg)
    uri = URI[p]
    --print("LuaSendMsg", pname, uids[1], sid)
    GoSendMsg(uri, _msg, sid, uids)
end

function update()
    --timer.update()
    TimerUpdate()
end

