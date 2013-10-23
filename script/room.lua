
require "utility"
require "guess"
require "gift"
require "db"

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
    self.round_info = {} -- {presenter, round_number}
    self.timer = Timer:new(self.sid)
    --self.timer:settimer(CHECK_PING_INTERVAL, nil, self.checkPing, self)
    self:checkPing()
    self.guess = nil
    self.giftmgr = GiftMgr:new(self.sid, self.presenters)
end

--self:SendMsg("S2CLoginRep", rep, {player.uid}) -- multi
function GameRoom.SendMsg(self, pname, msg, uids)
    SendMsg(pname, msg, uids, self.sid)
end

--self:Broadcast("S2CLoginRep", rep) -- all
function GameRoom.Broadcast(self, pname, msg)
    SendMsg(pname, msg, {}, self.sid)
end

function GameRoom.notifyStatus(self, st)
    self.status = st
    self:Broadcast("S2CNotifyStatus", {status = st})
end

function GameRoom.A(self)
    return self.presenters[1]
end

function GameRoom.B(self)
    return self.presenters[2]
end

function GameRoom.OnLogin(self, player, req)
    self.uid2player[req.uid] = player
    local rep = {
        ret = "OK",
        status = self.status,
        user = { },
    }
    rep.user.power = self.giftmgr:getPower(player.uid)
    player:SendMsg("S2CLoginRep", rep)

    if self.status == "Poll" then
        player:SendMsg("S2CNotfiyPunishOptions", 
            {options = self.giftmgr.options, loser = self:getLoser().user})
    elseif self.status == "Punish" then
        player:SendMsg("S2CNotfiyPunishOptions", 
            {options = self.giftmgr.options, loser = self:getLoser().user})
        player:SendMsg("S2CNotifyPunish", {punish = self.giftmgr:getPollResult()})
        player:SendMsg("S2CNotifyScores", {scores = self.scores})
    elseif self.status == "Round" and #self.round_info ~= 0 then
        t = ROUND_TIME - (os.time() - self.round_info[4])
        if t < 0 then return end
        player:SendMsg("S2CNotifyRoundStart", {
                presenter = {uid = self.round_info[1].uid},
                round = self.round_info[2],
                mot = {desc = self.round_info[3].desc},
                time = t,
            })
    end
end

function GameRoom.OnStartGame(self, player, req)
    if req.presenter.role == "PresenterA" then
        self.presenters[1] = player
    elseif req.presenter.role == "PresenterB" then
        self.presenters[2] = player
    else
        return
    end
    self.uid2player[player.uid].role = req.presenter.role

    local rep = {ret = "WAIT_OTHER"}
    if #self.presenters == 2 then    
        if self.presenters[1].uid == self.presenters[2].uid then
            print("same presenter error")
            self:OnStopGame()
            return
        end
        print("start sucess", self.sid)
        self:notifyStatus("Round")
        self.timer:settimer(5, 1, self.roundStart, self)
        self.timer:settimer(BC_TOPN_INTERVAL, nil, self.notifyTopn, self)
        self.giftmgr.presenters = self.presenters
        rep.ret = "OK"
    else 
        print("waiting other")
        local p = self.presenters[#self.presenters] or self.presenters[2]
        local bc = {presenter = {uid = p.uid}}
        self:Broadcast("S2CNotifyReady", bc)
    end
    player:SendMsg("S2CStartGameRep", rep)
end

function GameRoom.OnUnReady(self, player, req)
    if self.status == "Ready" then
        table.remove(self.presenters, 2)
    end
end

function GameRoom.roundStart(self)
    print("RoundStart")
    local motions = RandomMotion()
    if motions == nil then return end
    self:doRound(self:A(), 1, motions[1])
    for ar = 2, ROUND_COUNT do
        self.timer:settimer(ROUND_TIME * (ar-1), 1, self.doRound, self, self:A(), ar, motions[ar])
    end

    self.timer:settimer(ROUND_COUNT * ROUND_TIME, 1, self.notifyA2B, self)
    local a_total_time = ROUND_COUNT * ROUND_TIME + A2B_ROUND_INTERVAL
    for br = 1, ROUND_COUNT do
        local t = a_total_time + ROUND_TIME * (br - 1)
        self.timer:settimer(t, 1, self.doRound, self, self:B(), br, motions[br+ROUND_COUNT])
    end

    local round_end_time = a_total_time + ROUND_TIME * ROUND_COUNT + 1
    self.timer:settimer(round_end_time, 1, self.pollStart, self)

    local notify_score_count = round_end_time / BC_SCORE_INTERVAL + 1
    self.timer:settimer(BC_SCORE_INTERVAL, notify_score_count, self.notifyScore, self)
end

function GameRoom.doRound(self, presenter, r, m)
    print("DoRound", r)
    self.round_info = {presenter, r, m, os.time()}
    self.guess = Guess:new(m)
    local bc = {
        presenter = {uid = presenter.uid},
        round = r,
        mot = m,
        time = ROUND_TIME,
    }   
    self:Broadcast("S2CNotifyRoundStart", bc)
end

function GameRoom.notifyA2B(self)
    print("notifyA2B")
    self:Broadcast("S2CNotifyA2B", {defer = A2B_ROUND_INTERVAL,
            b = {uid = self.presenters[2].uid}})
end

function GameRoom.notifyScore(self)
    print("notifyScore", self.scores[1], self.scores[2])
    local bc = {scores = self.scores}
    self:Broadcast("S2CNotifyScores", bc)
end

function GameRoom.pollStart(self)
    print("pollStart")
    self:notifyStatus("Poll")
    local bc = {options = RandomPunish(), loser = self:getLoser().user}
    self.giftmgr.options = bc.options
    self:Broadcast("S2CNotfiyPunishOptions", bc)
    self.timer:settimer(POLL_TIME, 1, self.punishStart, self)
    self.timer:settimer(BC_POLLS_INTERVAL, POLL_TIME/2+1, self.notifyPolls, self)
end

function GameRoom.OnPoll(self, player, req)
    print("OnPoll")
    local r, p, idx = self.giftmgr:poll(player, req.punish_id)
    player:SendMsg("S2CPollRep", {ret = r})
    if p > 1 then
        self:Broadcast("S2CNotifyPowerPoll", {
                user = {
                    name = player.name,
                    power = p,
                },
                id = idx,
        })
    end
end

function GameRoom.notifyPolls(self)
    print("notifyPolls")
    self:Broadcast("S2CNotifyPolls", {polls = self.giftmgr.polls})
end

function GameRoom.punishStart(self)
    print("punishStart")
    self:notifyStatus("Punish")
    self:Broadcast("S2CNotifyPunish", {punish = self.giftmgr:getPollResult()})

    local auid, buid = self:A().uid, self:B().uid
    local ag1, bg1 = self.scores[1], self.scores[2]
    local ag2 = self.giftmgr.gift_score[auid] or 0
    local bg2 = self.giftmgr.gift_score[buid] or 0
    SaveRoundSidInfo({sid=self.sid, game_score=ag1+bg1, gift_score=ag2+bg2, total=ag1+ag2+bg1+bg2})
    SaveRoundUidInfo({uid=auid, game_score=ag1, gift_score=ag2, total=ag1+ag2})
    SaveRoundUidInfo({uid=buid, game_score=bg1, gift_score=bg2, total=bg1+bg2})
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
    if player then  
        if self.status ~= "Ready" and player.uid ~= self:A().uid and
                player.uid ~= self:B().uid then
            print("not presenter stop game")
            return
        end
        self:Broadcast("S2CNotifyChat", { msg = "", user = { name = player.name },
                                        type = STOP_PRESENTER_LEFT })
    end
    self:notifyStatus("Ready")

    for i, v in ipairs(self.presenters) do
        local p = self.uid2player[v.uid]
        if p then p.role = "Attendee" end
    end
    self:init()
end

function GameRoom.OnRegGift(self, player, req)
    print("OnRegGift")
    local rep = {token = ""}
    rep.token, rep.sn, rep.orderid = self.giftmgr:regGiftOrder(player.uid, req)
    player:SendMsg("S2CRegGiftRep", rep)
end

function GameRoom.OnGiftCb(self, op, from_uid, to_uid, gid, gcount, orderid)
    print("GameRoom.OnGiftCb", op, from_uid, to_uid, gid, gcount, orderid)
    if op == 1 then 
        GiftMgr.finishGift(from_uid, orderid)
    end

    local req, giver = GiftMgr.orderid2req[orderid], self.uid2player[from_uid]
    if giver then
        giver:SendMsg("S2CGiftRep", {op = op, orderid = orderid})
    end

    if not req or op ~= 1 then 
        -- not register or pay unsucess,  nothing to do with power
        SaveGift({orderid=orderid, step=STEP_GIFT_UNSUCESS, op_ret=op})
        return 
    end
    if self.status ~= "Ready" then
        self.giftmgr:increasePower(from_uid, to_uid, gid, gcount)
        self.giftmgr:increaseGiftScore(to_uid, gid, gcount)
    end
    GiftMgr.orderid2req[orderid] = nil

    local receiver =  self.uid2player[to_uid]
    local gname, rname, guid, ruid = "", "", 0, 0
    if receiver then 
        rname = receiver.name 
        ruid = receiver.uid
    end
    if giver then 
        gname = giver.name 
        guid = giver.uid
        self.giftmgr:sign(guid, gname)
    end
    local bc = {
        giver = {name = gname, uid = guid},
        receiver = {name = rname, uid = ruid},
        gift = {id = gid, count = gcount},
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
    if self.status == "Round" and self.guess then
        local ret, isfirst, answer = self.guess:guess(player, req.msg)
        bc.msg = answer
        bc.correct = ret
        if ret then
            if isfirst then
                self:addScore()
            else
                return
            end
        end
    end
    self:Broadcast("S2CNotifyChat", bc)
end

function  GameRoom.addScore(self)
    print("addScore")
    if self.round_info[1] == self.presenters[1] then
        self.scores[1] = self.scores[1] + BINGO_SCORE
    elseif self.round_info[1] == self.presenters[2] then
        self.scores[2] = self.scores[2] + BINGO_SCORE
    end
    print(table.concat(self.scores, " : "))
end

function GameRoom.getLoser(self)
    local idx = 1
    if self.scores[2] < self.scores[1] then
        idx = 2
    elseif self.scores[2] == self.scores[1] then
        idx = math.random(2)
    end
    return self.presenters[idx]
end

function GameRoom.notifyVips(self)
    print("notifyVips")
    local a, b = self.giftmgr:vips()
    self:Broadcast("S2CNotifyVips", {a_vip = a,  b_vip = b})
end

function GameRoom.notifyTopn(self)
    self:Broadcast("S2CNotifyTopnGiver", {topn = self.giftmgr:topn()})
end

function GameRoom.OnLogout(self, player, req)
    if not player then return end
    print("OnLogout", player.uid, player.role)
    if player:isPresenter() then 
        if self.status ~= "Ready" then
            self:OnStopGame(player)
        end
    end
    self.uid2player[player.uid] = nil
end

function GameRoom.OnPing(self, player, req)
    --player:SendMsg("S2CPingRep", {})
    player.lastping = os.time()
end

function GameRoom.checkPing(self)
    print("checkping")
    local now = os.time()
    for uid, player in pairs(self.uid2player) do
        if now - player.lastping > PING_LOST then
            print("ping lost", uid)
            self:OnLogout(player)
        end
    end
end

function GameRoom.OnInvildProto(self, uid, pname)
    print("not login yet", uid, pname)
    self:SendMsg("S2CReLogin", {}, {uid})
end

