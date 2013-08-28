
require "utility"
require "motion"
require "const"

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

function GameRoom.SendMsg(self, pname, msg, uids)
    SendMsg(pname, msg, uids, self.sid)
end

function GameRoom.Broadcast(self, pname, msg)
    SendMsg(pname, msg, {}, self.sid)
end

function GameRoom.OnLogin(self, player, req)
    self.uid2player[req.uid] = player
    rep = {
        ret = "OK",
        status = "Ready",
        user = {
            role = "Attendee",
        },
    }
    --self:SendMsg("S2CLoginRep", rep, {player.user.uid}) -- multi
    --self:Broadcast("S2CLoginRep", rep) -- all
    player:SendMsg("S2CLoginRep", rep)  -- single
end

function GameRoom.OnStarGame(self, player, req)
    if req.presenter.role == "PresenterA" then
        self.presenter[1] = player
    elseif req.presenter.role == "PresenterB" then
        self.presenter[2] = player
    else
        print("false")
    end

    rep = {ret = "WAIT_OTHER"}
    if table.getn(self.presenters) == 2 then    
        print("start sucess")
        local bc = {status="Round"}
        self:Broadcast("S2CNotifyStatus", bc)
        timer.settimer(5, 1, self.RoundStart, self)
    else 
        print("waiting other")
    end
end

function GameRoom.roundStart(self)
    print("RoundStart")
    self.status = "Round"
    local a, b = self.presenters[1],  self.presenters[2]
    local ar, br = 1, 1

    self:doRound(a, ar)
    while ar < ROUND_COUNT do
        ar = ar + 1
        timer.settimer(ROUND_TIME * ar, 1, self.doRound, self, a, ar)
    end

    local a_total_time = (ROUND_COUNT - 1) * ROUND_TIME + A2B_ROUND_INTERVAL
    while br < ROUND_COUNT do 
        local t = a_total_time + ROUND_TIME * (br - 1)
        timer.settimer(t, 1, self.doRound, self, b, br)
        br = br + 1
    end
end

function GameRoom.doRound(self, presenter, r)
    print("DoRound")
    local m = RandomMotion()
    local bc = {
        presenter = {uid = presenter.user.uid},
        round = r,
        mot = {id = m.id, desc = m.desc },
    }   
    self:Broadcast("S2CNotifyRoundStart", bc)
end

function GameRoom.OnChat(self, player, req)
    bc = {
        msg = req.msg, 
        user = {
            uid = player.user.uid,
            name = player.user.name,
        }
    }
    self:Broadcast("S2CNotifyChat", bc)
end

function GameRoom.OnLogout(self, player, req)
end

