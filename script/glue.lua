package.path = "/Users/lsaint/Documents/SRC/pbc/binding/lua/?.lua;" .. package.path
package.path = "/Users/lsaint/go/src/act/script/?.lua;" .. package.path
package.path = "/Users/lsaint/go/src/act/db/?.lua;" .. package.path
package.cpath = "/Users/lsaint/Documents/SRC/pbc/binding/lua/?.so;" .. package.cpath

protobuf = require "protobuf"
parser = require "parser"
watchdog = require "watchdog"

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
    _msg = protobuf.encode(pname, msg)
    --print("len", string.len(_msg))
    uri = URI[pname]
    GoSendMsg(uri, _msg, sid, uids)
end

function Broadcast(pname, msg, sid)
    SendMsg(pname, msg, {}, sid)
end

