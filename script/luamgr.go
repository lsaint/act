package script

import (
    "fmt"
    "encoding/binary"

    pb "code.google.com/p/goprotobuf/proto"
    "github.com/aarzilli/golua/lua"

    "act/proto"
    "act/postman"
)

const (
    MAX_STATE = 2
)


type StateInPack struct {
    sid         float64
    uid         float64    
    pname       string
    data        string
}

type LuaState struct {
    state               *lua.State
    stateInChan         chan *StateInPack
    stateOutChan        chan *proto.GateOutPack
    pm                  *postman.Postman             
}

func NewLuaState(out chan *proto.GateOutPack) *LuaState {
    ls := &LuaState{lua.NewState(), make(chan *StateInPack, 10), out, postman.NewPostman()}
    ls.state.OpenLibs()
    ls.state.DoFile("./script/glue.lua")
    RegisterLuaFunction(ls)
    go ls.loop()
    return ls
}

func (this *LuaState) loop() {
    for {
        select {
            case pack := <-this.stateInChan:
                this.invokeLua(pack)
        }
    }
}

func (this *LuaState) invokeLua(pack *StateInPack) {
    fmt.Println("stateInChan")
    defer func() {
        if r := recover(); r != nil {
            fmt.Println("Lua Err:", r)
        }
    }()
    this.state.GetGlobal("dispatch")
    this.state.PushNumber(pack.sid)
    this.state.PushNumber(pack.uid)
    this.state.PushString(pack.pname)
    this.state.PushString(pack.data)
    if lerr := this.state.Call(4, 0); lerr != nil {
        this.state.RaiseError("---")
    }
}


type LuaMgr struct {
    hash2state       map[uint32]*LuaState
    recvChan        chan *proto.GateInPack
    sendChan        chan *proto.GateOutPack
}

func NewLuaMgr() *LuaMgr {
    mgr := &LuaMgr{hash2state: make(map[uint32]*LuaState)}
    return mgr
}

func (this *LuaMgr) Start(out chan *proto.GateOutPack, in chan *proto.GateInPack) {
    fmt.Println("LuaMgr running")
    this.sendChan, this.recvChan = out, in
    for {
        select {
            case pack := <-this.recvChan:
                fmt.Println("luamgr recv")
                h := pack.GetHeader()
                uid, sid := h.GetUid(), h.GetSid()
                pname := proto.URI2PROTO[pack.GetUri()].Name()[3:]
                state := this.GetLuaState(sid)
                state.stateInChan <- &StateInPack{float64(sid), float64(uid), pname,
                                        string(pack.GetBin())}
        }
    }
}

func (this *LuaMgr)GetLuaState(sid uint32) *LuaState {
     hash := sid % MAX_STATE   
     state, exist := this.hash2state[sid] 
     if !exist {
        state = NewLuaState(this.sendChan)
        this.hash2state[hash] = state
     }
     return state
}


func RegisterLuaFunction(LS *LuaState) {

    // arg1: uri        uint32
    // arg2: msg        string
    // arg3: sid        uint32
    // arg4: uids       []uint32
    Lua_SendMsg := func(L *lua.State) int {
        uri := uint32(L.ToInteger(1))
        msg := L.ToString(2)
        sid := uint32(L.ToInteger(3))
        len_uids := int(L.ObjLen(4))
        var uids []uint32
        for i:=1; i<=len_uids; i++ {
            L.RawGeti(4, i)
            uid := L.ToInteger(-1)
            uids = append(uids, uint32(uid))
            //L.Pop(1)
        }
        fmt.Println(len(msg), uids, sid, uri)

        uri_field := make([]byte, 4)
        binary.LittleEndian.PutUint32(uri_field, uri)
        data := []byte(msg)
        data = append(uri_field, data...)

        LS.stateOutChan <- &proto.GateOutPack{Uids: uids, Sid: pb.Uint32(sid), Bin: data}
        return 0
    }

    // arg1: post_string    string
    Lua_Post := func(L *lua.State) int {
        post_string := L.ToString(1)
        ret := LS.pm.Post(post_string)
        L.PushString(ret)
        return 1
    }

    LS.state.Register("GoSendMsg", Lua_SendMsg)
    LS.state.Register("GoPost", Lua_Post)
}



