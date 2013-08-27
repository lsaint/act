

Player = {}
Player.__index = Player

function Player.new(user_data)
    local self = setmetatable({}, Player)
    print("type-self", type(self))
    self.user = user_data
    return self
end

function Player.print(self)
    for k, v in pairs(self.user) do
        print(k, v)
    end
end
