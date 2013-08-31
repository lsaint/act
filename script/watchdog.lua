
require "room"
require "player"

local function WatchDog()
    local self = {
        sid2room = {}
    }

    function self.dispatch(sid, uid, pname, data)
        local room = self.sid2room[sid]
        if room == nil then
            room = GameRoom.new(sid)
            self.sid2room[sid] = room
        end
        local proto_name = string.format("%s%s", "proto.C2S", pname)
        local req = protobuf.decode(proto_name, data)
        local player = room.uid2player[uid]
        if player == nil and pname == "Login" then
            player = Player:new(req.user)
            room.uid2player[uid] = player
        end
        local method = string.format("On%s", pname)
        print(string.format("%s%s%s", "---------", pname, "---------"))
        --pt(req)
        room[method](room, player, req)
    end
    return self
end 

local watchdog = WatchDog()
return watchdog
