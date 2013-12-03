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
    NET_CTRL  = iota
    POST_DONE = iota
)


type StateInPack struct {
    tsid        float64
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
    ctrlChan            chan string
}

func NewLuaState(out chan *proto.GateOutPack) *LuaState {
    ls := &LuaState{lua.NewState(), 
                    make(chan *StateInPack, 1024), 
                    out, postman.NewPostman(),
                    make(chan *proto.GiftCbPack, 1024),
                    make(chan string, 64)}
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
            case s := <-this.ctrlChan:
                this.invokeLua(NET_CTRL, s)
            case post_ret := <-this.pm.DoneChan:
                this.invokeLua(POST_DONE, post_ret.Sn, <-post_ret.Ret)
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
        case NET_CTRL:
            s, _ := args[0].(string)
            err = this.onNetCtrl(s)
        case POST_DONE:
            sn, _ := args[0].(int64)
            ret, _ := args[1].(string)
            err = this.onPostDone(sn, ret)
    }
    if err != nil {
        this.doPrintingErrors(err)
    }
}

func (this *LuaState) onProto(pack *StateInPack) error {
    this.state.GetGlobal("dispatch")
    this.state.PushNumber(pack.tsid)
    this.state.PushNumber(pack.sid)
    this.state.PushNumber(pack.uid)
    this.state.PushString(pack.pname)
    this.state.PushString(pack.data)
    return this.state.Call(5, 0)
}

func (this *LuaState) onUpdate() error {
    this.state.GetGlobal("update") 
    return this.state.Call(0, 0)
}

func (this *LuaState) onGiftCb(pack *proto.GiftCbPack) error {
    this.state.GetGlobal("giftCb") 
    this.state.PushString(pack.GetOp())
    this.state.PushString(pack.GetTsid())
    this.state.PushString(pack.GetFromUid())
    this.state.PushString(pack.GetToUid())
    this.state.PushString(pack.GetGiftId())
    this.state.PushString(pack.GetGiftCount())
    this.state.PushString(pack.GetOrderId())
    return this.state.Call(7, 0)
}

func (this *LuaState) onNetCtrl(s string) error {
    this.state.GetGlobal("netCtrl")
    this.state.PushString(s)
    return this.state.Call(1, 0)
}

func (this *LuaState) onPostDone(sn int64, ret string) error {
    this.state.GetGlobal("postDone")
    this.state.PushInteger(sn)
    this.state.PushString(ret)
    return this.state.Call(2, 0)
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
    ctrl := postman.NewNetCtrl()
    go ctrl.Start()
    for i:=0; i<int(common.CF.MaxState); i++ {
        this.hash2state[uint32(i)] = NewLuaState(this.sendChan)
    }
    for {
        select {
            case pack := <-this.recvChan:
                h := pack.GetHeader()
                uid, sid, tsid := h.GetUid(), h.GetSid(), h.GetTsid()
                pname := proto.URI2PROTO[uint16(pack.GetUri())].Name()[3:]
                state := this.GetLuaState(tsid)
                state.stateInChan <- &StateInPack{float64(tsid), float64(sid), 
                                                    float64(uid), pname,
                                                    string(pack.GetBin())}

            case pack := <-httpCb.GiftCbChan:
                if tsid, err := strconv.ParseUint(pack.GetTsid(), 10, 64); err == nil {
                    state := this.GetLuaState(uint32(tsid))
                    state.giftCbChan <- pack
                }

            case s := <-ctrl.CtrlChan:
                for _, state := range this.hash2state {
                    state.ctrlChan <- s
                }
        }
    }
}

func (this *LuaMgr)GetLuaState(tsid uint32) *LuaState {
    hash := tsid % common.CF.MaxState
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
    // arg4: tsid       uint32
    // arg5: uids       []uint32
    // return: nil
    Lua_SendMsg := func(L *lua.State) int {
        uri := uint16(L.ToInteger(1))
        msg := L.ToString(2)
        tsid := uint32(L.ToInteger(3))
        sid := uint32(L.ToInteger(4))
        len_uids := int(L.ObjLen(5))
        var uids []uint32
        for i:=1; i<=len_uids; i++ {
            L.RawGeti(5, i)
            uid := L.ToInteger(-1)
            uids = append(uids, uint32(uid))
            //L.Pop(1)
        }

        uri_field := make([]byte, 2)
        binary.LittleEndian.PutUint16(uri_field, uri)
        data := []byte(msg)
        data = append(uri_field, data...)

        LS.stateOutChan <- &proto.GateOutPack{Uids: uids, Sid: pb.Uint32(sid), 
                                              Tsid: pb.Uint32(tsid), Bin: data}
        return 0
    }

    // arg1: url                string
    // arg2: post_content       string
    // arg3: sn                 int64
    // return: post result's raw string
    Lua_PostAsync := func(L *lua.State) int {
        url := L.ToString(1)
        post_string := L.ToString(2)
        sn := L.ToInteger(3)
        LS.pm.PostAsync(url, post_string, int64(sn))
        return 0
    }

    // arg1: url                string
    // arg2: post_content       string
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
    LS.state.Register("goPostAsync", Lua_PostAsync)
    LS.state.Register("GoMd5", Lua_Md5)
    LS.state.Register("GoGetSn", Lua_GetSn)
}



