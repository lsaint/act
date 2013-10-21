package script

import (
    "io"
    "fmt"
    "time"
    "sync/atomic"
    "encoding/binary"
    "crypto/md5"
    "strconv"

    pb "code.google.com/p/goprotobuf/proto"
    "github.com/aarzilli/golua/lua"

    "act/common"
    "act/proto"
    "act/postman"
)

var SN int64
const (
    PROTO_INVOKE = iota
    UPDATE_INVOKE = iota
    CB_INVOKE = iota
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
    giftCbChan          chan *proto.GiftCbPack
}

func NewLuaState(out chan *proto.GateOutPack) *LuaState {
    ls := &LuaState{lua.NewState(), make(chan *StateInPack, 10), out, postman.NewPostman(),
                        make(chan *proto.GiftCbPack, 64)}
    ls.state.OpenLibs()
    if err := ls.state.DoFile("./script/glue.lua"); err != nil {
        ls.doPrintingErrors(err)
        panic("lua do file err")
    }
    RegisterLuaFunction(ls)
    go ls.loop()
    return ls
}

func (this *LuaState) doPrintingErrors(err error) {
    if err != nil {
        if lerr, ok := err.(*lua.LuaError); ok {
            fmt.Printf("Lua err: %s %d\n", lerr.Error(), len(lerr.StackTrace()))
            for _, e := range lerr.StackTrace() {
                fmt.Printf("\tat %s:%d in %s\n", e.ShortSource, e.CurrentLine, e.Name)
            }
        } else {
            fmt.Printf("Error executing lua code: %s\n", err.Error())
        }
    }
}

func (this *LuaState) loop() {
    ticker := time.Tick(1 * time.Second)
    for {
        select {
            case pack := <-this.stateInChan:
                this.invokeLua(PROTO_INVOKE, pack)
            case <-ticker:
                this.invokeLua(UPDATE_INVOKE)
            case pack := <-this.giftCbChan:
                this.invokeLua(CB_INVOKE, pack)
        }
    }
}

func (this *LuaState) invokeLua(t int, args ...interface{}) {
    defer func() {
        if r := recover(); r != nil {
            fmt.Println("Lua Err:", r)
        }
    }()
    var err error
    switch t {
        case PROTO_INVOKE:
            pack, _ := args[0].(*StateInPack)
            err = this.onProto(pack)
        case UPDATE_INVOKE:
            err = this.onUpdate()
        case CB_INVOKE:
            pack, _ := args[0].(*proto.GiftCbPack)
            err = this.onGiftCb(pack)
    }
    if err != nil {
        this.doPrintingErrors(err)
    }
}

func (this *LuaState) onProto(pack *StateInPack) error {
    this.state.GetGlobal("dispatch")
    this.state.PushNumber(pack.sid)
    this.state.PushNumber(pack.uid)
    this.state.PushString(pack.pname)
    this.state.PushString(pack.data)
    return this.state.Call(4, 0)
}

func (this *LuaState) onUpdate() error {
    this.state.GetGlobal("update") 
    return this.state.Call(0, 0)
}

func (this *LuaState) onGiftCb(pack *proto.GiftCbPack) error {
    this.state.GetGlobal("giftCb") 
    this.state.PushString(pack.GetOp())
    this.state.PushString(pack.GetSid())
    this.state.PushString(pack.GetFromUid())
    this.state.PushString(pack.GetToUid())
    this.state.PushString(pack.GetGiftId())
    this.state.PushString(pack.GetGiftCount())
    this.state.PushString(pack.GetOrderId())
    return this.state.Call(7, 0)
}

////

type LuaMgr struct {
    hash2state       map[uint32]*LuaState
    recvChan        chan *proto.GateInPack
    sendChan        chan *proto.GateOutPack
    giftCbChan      chan *proto.GiftCbPack
}

func NewLuaMgr() *LuaMgr {
    mgr := &LuaMgr{hash2state: make(map[uint32]*LuaState)}
    return mgr
}

func (this *LuaMgr) Start(out chan *proto.GateOutPack, in chan *proto.GateInPack) {
    fmt.Println("LuaMgr running")
    this.sendChan, this.recvChan = out, in
    httpCb := postman.NewHttpCb()
    go httpCb.Start()
    for i:=0; i<int(common.CF.GetMaxState()); i++ {
        this.hash2state[uint32(i)] = NewLuaState(this.sendChan)
    }
    for {
        select {
            case pack := <-this.recvChan:
                //fmt.Println("luamgr recv")
                h := pack.GetHeader()
                uid, sid := h.GetUid(), h.GetSid()
                pname := proto.URI2PROTO[uint16(pack.GetUri())].Name()[3:]
                state := this.GetLuaState(sid)
                state.stateInChan <- &StateInPack{float64(sid), float64(uid), pname,
                                        string(pack.GetBin())}

            case pack := <-httpCb.GiftCbChan:
                if sid, err := strconv.ParseUint(pack.GetSid(), 10, 64); err == nil {
                    state := this.GetLuaState(uint32(sid))
                    state.giftCbChan <- pack
                }
        }
    }
}

func (this *LuaMgr)GetLuaState(sid uint32) *LuaState {
    hash := sid % common.CF.GetMaxState()   
    state, exist := this.hash2state[hash] 
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
    // return: nil
    Lua_SendMsg := func(L *lua.State) int {
        uri := uint16(L.ToInteger(1))
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
        //fmt.Println(len(msg), uids, sid, uri)

        uri_field := make([]byte, 2)
        binary.LittleEndian.PutUint16(uri_field, uri)
        data := []byte(msg)
        data = append(uri_field, data...)

        LS.stateOutChan <- &proto.GateOutPack{Uids: uids, Sid: pb.Uint32(sid), Bin: data}
        return 0
    }

    // arg1: post_string    string
    // return: post result's raw string
    Lua_Post := func(L *lua.State) int {
        url := L.ToString(1)
        post_string := L.ToString(2)
        ret := LS.pm.Post(url, post_string)
        L.PushString(ret)
        return 1
    }

    // arg1: string to md5
    // return: md5 string
    Lua_Md5 := func(L *lua.State) int {
        to_md5 := L.ToString(1)
        m5 := md5.New()
        io.WriteString(m5, to_md5)
        L.PushString(fmt.Sprintf("%x", m5.Sum(nil)))
        return 1
    }

    // return: not repeated sn
    Lua_GetSn := func(L *lua.State) int {
        L.GetGlobal("SRVID")
        offset := int64(L.ToInteger(-1) * 10000000000)
        L.PushInteger(atomic.AddInt64(&SN, 1) + int64(time.Now().Unix()) + offset)
        return 1
    }

    LS.state.Register("GoSendMsg", Lua_SendMsg)
    LS.state.Register("GoPost", Lua_Post)
    LS.state.Register("GoMd5", Lua_Md5)
    LS.state.Register("GoGetSn", Lua_GetSn)
}



