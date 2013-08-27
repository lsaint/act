
require "utility"

GameRoom = {}
GameRoom.__index = GameRoom

function GameRoom.new(sid)
   local self = setmetatable({}, GameRoom)
   self.sid = sid
   self.uid2player = {}
   self.presenters = {}
   self.status = "Ready"
   return self
end

function GameRoom.OnLogin(self, player, req)
    rep = {
        ret = "OK",
        status = "Ready",
        user = {
            role = "Attendee",
        },
    }
    SendMsg("proto.S2CLoginRep", rep, {player.user.uid}, 0)
end


function GameRoom.OnStarGame(self, player, req)
    if req.presenter.role == "PresenterA" then
        self.presenter[1] = player
    elseif req.presenter.role == "PresenterB" then
        self.presenter[2] = player
    else
        print("false")
    end

    if self.pr
end

