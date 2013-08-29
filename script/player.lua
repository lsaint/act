

Player = {}
Player.__index = Player

function Player.new(user_data)
    local self = setmetatable({}, Player)
    self.user = user_data
    return self
end

function Player.print(self)
    for k, v in pairs(self.user) do
        print(k, v)
    end
end

function Player.SendMsg(self, pname, msg)
    SendMsg(pname, msg, {self.user.uid}, 0)
end
