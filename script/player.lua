

Player = {}

function Player:new(user_data)
    self.__index = self
    local ins = setmetatable({}, self)
    ins.lastping = os.time()
    ins.user = user_data
    ins:init()
    return ins      
end

function Player:SendMsg(pname, msg)
    SendMsg(pname, msg, {self.uid}, 0)
end

function Player:init()
    self.uid            =          self.user.uid                  
    self.name           =          self.user.name 
    self.imid           =          self.user.imid 
    self.sex            =          self.user.sex 
    self.privilege      =          self.user.privilege 
    self.role           =          "Attendee"
end

function Player:isAorB()
    return string.find(self.role, "Presenter") ~= nil or
            string.find(self.role, "Candidate") ~= nil
end

