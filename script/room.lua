
require "utility"
require "motion"
require "const"
require "punish"
require "guess"
require "gift"

GameRoom = {}
GameRoom.__index = GameRoom

function GameRoom.new(sid)
    local self = setmetatable({}, GameRoom)
    self.sid = sid
    self.uid2player = {}
    self.status = "Ready"
    self:init()
    return self
end

function GameRoom.init(self)
    print("init")
    self.presenters = {}
    self.over = {}
    self.scores = {0, 0}
    self.round_info = {}
    self.timer = Timer:new(self.sid)
    self.guess = nil
    self.giftmgr =  nil
end

function GameRoom.SendMsg(self, pname, msg, uids)
    SendMsg(pname, msg, uids, self.sid)
end

function GameRoom.Broadcast(self, pname, msg)
    SendMsg(pname, msg, {}, self.sid)
end

function GameRoom.notifyStatus(self, st)
    self.status = st
    self:Broadcast("S2CNotifyStatus", {status = st})
end

function GameRoom.OnLogin(self, player, req)
    self.uid2player[req.uid] = player
    local rep = {
        ret = "OK",
        status = self.status,
        user = { },
    }
    --self:SendMsg("S2CLoginRep", rep, {player.uid}) -- multi
    --self:Broadcast("S2CLoginRep", rep) -- all
    player:SendMsg("S2CLoginRep", rep)  -- single
end

function GameRoom.OnStartGame(self, player, req)
    if req.presenter.role == "PresenterA" then
        self.presenters[1] = player
    elseif req.presenter.role == "PresenterB" then
        self.presenters[2] = player
    else
        return
    end

    local rep = {ret = "WAIT_OTHER"}
    if #self.presenters == 2 then    
        print("start sucess", self.sid)
        self:notifyStatus("Round")
        self.timer:settimer(5, 1, self.roundStart, self)
        local bc_vip_count = (TOTAL_ROUND_TIME + POLL_TIME) / BC_VIP_INTERVAL + 1
        self.timer:settimer(BC_VIP_INTERVAL, bc_vip_count, self.notifyVips, self)
        self.giftmgr = GiftMgr:new(self.sid, self.presenters)
        rep.ret = "OK"
    else 
        print("waiting other")
        local p = self.presenters[#self.presenters] or self.presenters[2]
        local bc = {presenter = {uid = p.uid}}
        self:Broadcast("S2CNotifyReady", bc)
    end
    player:SendMsg("S2CStartGameRep", rep)
end

function GameRoom.roundStart(self)
    print("RoundStart")
    local a, b = self.presenters[1],  self.presenters[2]
    local ar, br = 1, 1

    self:doRound(a, ar)
    while ar < ROUND_COUNT do
        ar = ar + 1
        self.timer:settimer(ROUND_TIME * ar, 1, self.doRound, self, a, ar)
    end

    local a_total_time = ROUND_COUNT * ROUND_TIME + A2B_ROUND_INTERVAL
    while br < ROUND_COUNT do 
        local t = a_total_time + ROUND_TIME * (br - 1)
        self.timer:settimer(t, 1, self.doRound, self, b, br)
        br = br + 1
    end

    local round_end_time = a_total_time + ROUND_TIME * (ROUND_COUNT - 1) + 1
    self.timer:settimer(round_end_time, 1, self.pollStart, self)

    local notify_score_count = round_end_time / BC_SCORE_INTERVAL + 1
    self.timer:settimer(BC_SCORE_INTERVAL, notify_score_count, self.notifyScore, self)
end

function GameRoom.doRound(self, presenter, r)
    print("DoRound", r)
    self.round_info = {presenter, r}
    local m = RandomMotion()
    self.guess = Guess:new(m)
    local bc = {
        presenter = {uid = presenter.uid},
        round = r,
        mot = {id = m.id, desc = m.desc },
    }   
    self:Broadcast("S2CNotifyRoundStart", bc)
end

function GameRoom.notifyScore(self)
    print("notifyScore")
    local bc = {scores = self.scores}
    self:Broadcast("S2CNotifyScores", bc)
end

function GameRoom.pollStart(self)
    print("pollStart")
    self:notifyStatus("Poll")
    local bc = {options = RandomPunish(), loser = self.presenters[1].user}
    self.giftmgr.options = bc.options
    self:Broadcast("S2CNotfiyPunishOptions", bc)
    self:Broadcast("S2CNotifyTop3Giver", self.giftmgr:top3())
    self.timer:settimer(POLL_TIME, 1, self.punishStart, self)
    self.timer:settimer(BC_POLLS_INTERVAL, POLL_TIME/2+1, self.notifyPolls, self)
end

function GameRoom.OnPoll(self, player, req)
    print("OnPoll")
    player:SendMsg("S2CPollRep", {ret = "OK"})
end

function GameRoom.notifyPolls(self)
    print("notifyPolls")
    self:Broadcast("S2CNotifyPolls", {polls = self.giftmgr.polls})
end

function GameRoom.punishStart(self)
    print("punishStart")
    self:notifyStatus("Punish")
end

function GameRoom.OnPunishOver(self, player, req)
    print("PunishOver")
    if #self.over >= 2 then return end
    table.insert(self.over, player)    
    local rep = {ret = "WAIT_OTHER"}
    if #self.over == 2 then
        self:OnStopGame()
        rep.ret = "OK"
    else 
        print("waiting other over")
        self:Broadcast("S2CNotifyPunishOver",
                {presenter = {uid = self.over[1].uid}})
    end
    player:SendMsg("S2CPunishOverRep", rep)
end

function GameRoom.OnStopGame(self, player, req)
    print("OnStopGame")
    if player ~= nil and string.find(player.role, "Presenter") == nil then
        print("no auth to stop", player.uid)
        return
    end
    self:notifyStatus("Ready")
    self:init()
end


function GameRoom.OnGift(self, player, req)
    print("OnGift")
    local rep = {ret = "OK", csn = req.csn}
    if self.giftmgr == nil then
        rep.ret = "FL"
    end
    player:SendMsg("S2CGiftRep", rep)

    self:OnGiftCb(player.uid, req.to_uid, req.gift, req.csn)
end

function GameRoom.OnGiftCb(self, from_uid, to_uid, gift, csn)
    print("OnGiftCb")
    local giver = self.uid2player[from_uid]
    local receiver = self.uid2player[to_uid]
    local rname = ""
    if receiver ~= nil then 
        rname = receiver.name 
    end
    local bc = {
        giver = {name = giver.name},
        receiver = {name = rname},
        gift = req.gift
    }
    self:Broadcast("S2CNotifyGift", bc)
end

function GameRoom.OnChat(self, player, req)
    local bc = {
        msg = req.msg, 
        user = {
            uid = player.uid,
            name = player.name,
        }
    }
    if self.status == "Round" then
        local ret, isfirst, answer = self.guess:guess(player, req.msg)
        bc.msg = answer
        bc.correct = ret
        if isfirst then self:addScore() end
    end
    self:Broadcast("S2CNotifyChat", bc)
end

function  GameRoom.addScore(self)
    print("addScore")
    if self.round_info[1] == self.presenters[1] then
        self.scores[1] = self.scores[1] + BINGO_SCORE
    elseif self.round_info[2] == self.presenters[2] then
        self.scores[2] = self.scores[2] + BINGO_SCORE
    end
end

function GameRoom.notifyVips(self)
    print("notifyVips")
    local a, b = self.giftmgr:vips()
    self:Broadcast("S2CNotifyVips", {a_vip = a,  b_vip = b})
end

function GameRoom.OnLogout(self, player, req)
    if player == nil then return end
    print("OnLogout", player.uid, player.role)
    if player.role == "PresenterA" or player.role == "PresenterB" then
        self:OnStopGame()
    else
        self.uid2player[player.uid] = nil
    end
end

