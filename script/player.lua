

Player = {}

function Player:new(user_data, sid)
    self.__index = self
    local ins = setmetatable({}, self)
    ins.lastping = os.time()
    ins.user = user_data
    ins.sid = sid
    ins:init()
    return ins      
end

function Player:SendMsg(pname, msg)
    SendMsg(pname, msg, {self.uid}, self.sid)
end

function Player:init()
    self.uid            =          self.user.uid                  
    self.name           =          self.user.name 
    self.imid           =          self.user.imid 
    self.sex            =          self.user.sex 
    self.privilege      =          self.user.privilege 
    self.role           =          self.user.role       
end

function Player:isAorB()
    return string.find(self.role, "Presenter") ~= nil or
            string.find(self.role, "Candidate") ~= nil
end

