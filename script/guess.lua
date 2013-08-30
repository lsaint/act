

Guess = {}

function Guess:new()
    setmetatable({}, self)
    self.__index = self
    self.bingo_players = {}
    self.correct_answer = "lsaint"
    return self
end

function Guess:guess(player, answer)
    local first_bingo = (self.bingo_players[player.uid] == true)
    local ret = self:check(answer)
    if ret == true and first_bingo ~= true then
        self.bingo_players[player.uid] = true
    end
    if ret == true then
        answer = "***"
    end
    return ret, first_bingo, answer
end

function Guess:check(answer)
    return string.find(answer, self.correct_answer) or false
end
