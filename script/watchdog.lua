
require "room"
require "player"

local function WatchDog()
    local self = {
        sid2room = {}
    }

    function self.gainRoom(sid)
        local room = self.sid2room[sid]
        if room == nil then
            room = GameRoom.new(sid)
            self.sid2room[sid] = room
        end
        return room
    end

    function self.dispatch(sid, uid, pname, data)
        local room = self.gainRoom(sid)
        local proto_name = string.format("%s%s", "proto.C2S", pname)
        local req = protobuf.decode(proto_name, data)
        local player = room.uid2player[uid]
        if not player then 
            if pname == "Login" then
                player = Player:new(req.user)
                room.uid2player[uid] = player
            else
                print("not login yet", uid, pname)
                return
            end
        end
        local method = string.format("On%s", pname)
        --print(string.format("%s%s%s", "---------", pname, "---------"))
        room[method](room, player, req)
    end

    function self.giftCb(op, sid, uid, touid, gid, gcount, orderid)
        local room = self.gainRoom(tonumber(sid))
        room:OnGiftCb(tonumber(op), tonumber(uid), tonumber(touid), tonumber(gid), tonumber(gcount), orderid)
    end

    return self
end 

local watchdog = WatchDog()
return watchdog
