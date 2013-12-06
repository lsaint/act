
require "guess"

RoundMgr = {}


function RoundMgr:new(room)
    self.__index = self
    local rt = {MODE_ACT = ROUND_TIME, MODE_FREE = ROUND_TIME_FREE}
    local ins = setmetatable({}, self)
    ins.room = room
    ins.mode2start = {MODE_ACT = ins.startRoundAct, MODE_FREE = ins.startRoundFree}
    ins.mode2abort = {MODE_ACT = ins.abortRoundAct, MODE_FREE = ins.abortRoundFree}
    ins.roundTotal = {MODE_ACT = ROUND_COUNT*2, MODE_FREE = 2}
    ins.roundNum = 0
    ins.roundTimerId = 0
    ins.motions = nil
    ins.roundTime = rt[room.mode]
    ins.startTime = os.time()
    ins.last_abort = os.time()
    return ins
end

function RoundMgr:RoundStart()
    print("RoundStart")
    self.mode2start[self.room.mode](self)
    self.room:settimer(BC_SCORE_INTERVAL, nil, self.room.notifyScore, self.room)
end

function RoundMgr:startRoundAct()
    print("startRoundAct")
    self.motions = RandomMotion({public=ROUND_COUNT*2-1, private=1, sid=self.room.tsid})
    if self.motions == nil then 
        print("get motions err")
        return 
    end
    self:doRoundAct()
end

function RoundMgr:startRoundFree()
    print("startRoundFree")
    self:doRoundFree()
end

function RoundMgr:doRoundAct()
    self:doRound()
    if self.roundNum == ROUND_COUNT then           -- B turn
        self.roundTimerId = self.room:settimer(ROUND_TIME+A2B_ROUND_INTERVAL, 1, 
                                                self.doRoundAct, self)
        self.notifyTimerId = self.room:settimer(ROUND_TIME, 1, self.notifyA2B, self)
    elseif self.roundNum == ROUND_COUNT * 2 then    -- end
        self.roundTimerId = self.room:settimer(ROUND_TIME, 1, self.room.pollStart, self.room)
    else                                 -- next round
        self.roundTimerId = self.room:settimer(ROUND_TIME, 1, self.doRoundAct, self)
    end
end

function RoundMgr:abortRoundAct()
    if self.roundNum == ROUND_COUNT then
        self.room.timer:rmtimer(self.roundTimerId)
        self.room.timer:activeTimer(self.notifyTimerId)
        self.roundTimerId = self.room:settimer(A2B_ROUND_INTERVAL, 1, self.doRoundAct, self)
    elseif self.roundNum == ROUND_COUNT * 2 then    -- end
        self.room.timer:rmtimer(self.roundTimerId)
        self.room:pollStart()
    else
        self.room.timer:activeTimer(self.roundTimerId)
    end
end

function RoundMgr:doRoundFree()
    self:doRound()
    if self.roundNum == 1 then                     -- B turn
        self.notifyTimerId = self.room:settimer(ROUND_TIME_FREE, 1, self.notifyA2B, self)
        self.roundTimerId = self.room:settimer(ROUND_TIME_FREE+A2B_ROUND_INTERVAL, 1, 
                                                self.doRoundFree, self)
        return 
    end
    -- end
    self.roundTimerId = self.room:settimer(ROUND_TIME_FREE, 1, self.room.pollStart, self.room)
end

function RoundMgr:abortRoundFree()
    if self.roundNum == 1 then
        self.room.timer:activeTimer(self.notifyTimerId)
        self.roundTimerId = self.room:settimer(A2B_ROUND_INTERVAL, 1, self.doRoundFree, self)
    else
        self.room.timer:rmtimer(self.roundTimerId)
        self.room:pollStart()
    end

end

function RoundMgr:AbortRound(player, rn)
    print("AbortRound", rn)
    if player ~= self:GetCurPresenter() then
        print("abort wrong presenter")
        return false
    end
    if rn ~= self.roundNum or rn == 0 then
        print("abort wrong round", rn, self.roundNum)
        return false
    end
    if os.time() - self.last_abort < LIMIT_ABORT then
        print("abort cd")
        return false
    end
    self.last_abort = os.time()
    self.mode2abort[self.room.mode](self)
    return true
end

function RoundMgr:doRound()
    self.roundNum = self.roundNum + 1
    print("DoRound", self.roundNum)
    local m = self:GetCurMotion()
    self.room.guess = Guess:new(m)
    local bc = {
        presenter = {uid = self:GetCurPresenter().uid},
        round = self.roundNum,
        mot = m,
        time = self.roundTime,
    }   
    self.room:Broadcast("S2CNotifyRoundStart", bc)
    self.startTime = os.time()
end

function RoundMgr:notifyA2B()
    print("notifyA2B")
    self.room:Broadcast("S2CNotifyA2B", {defer = A2B_ROUND_INTERVAL, b = {uid = self.room:B().uid}})
end

function RoundMgr:GetRemainTime()
    return self.roundTime - (os.time() - self.startTime)
end

function RoundMgr:GetCurMotion()
    local m = nil
    if self.motions then 
        m = self.motions[self.roundNum]
    end
    return m
end

function RoundMgr:GetCurPresenter()
    if self.room.mode == "MODE_ACT" and self.roundNum > ROUND_COUNT then
        return self.room:B()
    end

    if self.room.mode == "MODE_FREE" and self.roundNum == 2 then
        return self.room:B()
    end

    return self.room:A()
end

