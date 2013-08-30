

Player = {}
--Player.__index = Player

function Player:new(user_data)
    --local self = setmetatable(user_data, Player)
    user_data = user_data or {}
    setmetatable(user_data, self)
    self.__index = self
    self.user = user_data
    return self
end

function Player:SendMsg(pname, msg)
    SendMsg(pname, msg, {self.user.uid}, 0)
end
