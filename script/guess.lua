

Guess = {}

function Guess:new(m)
    self.__index = self
    local ins = setmetatable({}, self)
    ins.bingo_players = {}
    ins.correct_answer = m
    return ins
end

function Guess:guess(player, answer)
    local first_bingo = (self.bingo_players[player.uid] == nil)
    local ret = self:check(answer)
    if ret and first_bingo then
        self.bingo_players[player.uid] = true
    end
    if ret then
        answer = ""
    end
    return ret, first_bingo, answer
end

function Guess:check(answer)
    return string.find(answer, self.correct_answer.desc) ~= nil
end
