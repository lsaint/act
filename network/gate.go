package network

import (
    "fmt"
    "net"
    "reflect"
    "encoding/binary"

    pb "code.google.com/p/goprotobuf/proto"

    "act/proto"
)

type GateSendRecver interface {
    Start(out chan *proto.GateOutPack, in chan *proto.GateInPack)
}


type GateServer struct {
    buffChan        chan *ConnBuff
    conn2gheader    map[*ClientConnection]*proto.GateInHeader
    uid2conn        map[uint32]*ClientConnection
    sid2conns       map[uint32][]*ClientConnection
    GateEntry       chan *proto.GateInPack
    GateExit        chan *proto.GateOutPack
}

func NewGateServer(sendrecver GateSendRecver) *GateServer {
    gs := &GateServer{buffChan: make(chan *ConnBuff),
                        conn2gheader: make(map[*ClientConnection]*proto.GateInHeader),
                        uid2conn: make(map[uint32]*ClientConnection),
                        sid2conns: make(map[uint32][]*ClientConnection),
                        GateEntry: make(chan *proto.GateInPack, 1024),
                        GateExit: make(chan *proto.GateOutPack, 1024)}
    go sendrecver.Start(gs.GateExit, gs.GateEntry)
    go gs.parse()
    return gs
}


func (this *GateServer) Start() {
    ln, err := net.Listen("tcp", ":13829")                                                                            
    if err != nil {
        fmt.Println("Listen err", err)
        return
    }
    fmt.Println("gateServer runing")
    for {
        conn, err := ln.Accept()
        if err != nil {
            fmt.Println("Accept error", err)
            continue
        }
        go this.acceptConn(conn)
    }
}

func (this *GateServer) acceptConn(conn net.Conn) {
    //defer func() {
    //    if r := recover(); r != nil {
    //        fmt.Println("parse err", r)
    //    }
    //}()

    cliConn := NewClientConnection(conn)
    for {
        if buff_body, ok := cliConn.duplexReadBody(); ok {
            this.buffChan <- &ConnBuff{cliConn, buff_body}
            continue
        }
        this.buffChan <- &ConnBuff{cliConn, nil}
        break
    }
}

func (this *GateServer) parse() {
    for {
        select {
            case conn_buff := <-this.buffChan :
                msg := conn_buff.buff
                conn := conn_buff.conn

                if msg == nil {
                    this.Logout(conn)
                    continue
                }

                uri := binary.LittleEndian.Uint16(msg[:LEN_URI])
                var gheader *proto.GateInHeader
                if uri == 1 { // Login
                    pb_msg := reflect.New(proto.URI2PROTO[uri]).Interface().(pb.Message)
                    err := pb.Unmarshal(msg[LEN_URI:], pb_msg)
                    if err != nil {
                        fmt.Println("pb Unmarshal err", err)
                        break
                    }
                    if gheader = this.Login(conn, pb_msg); gheader == nil {
                        continue
                    }
                } else if uri == 0 {
                    this.Logout(conn)
                    continue
                } else {
                    gheader = this.conn2gheader[conn]
                }
                this.GateEntry <-&proto.GateInPack{Header: gheader, 
                                            Uri: pb.Uint32(uint32(uri)), Bin: msg[LEN_URI:]}

            case gop := <-this.GateExit :
                //fmt.Println("gateout:", gop.GetSid(), gop.GetUids(), len(gop.GetBin()))
                uids := gop.GetUids()
                if len(uids) != 0 {
                    for _, uid := range uids {
                        if conn, ok := this.uid2conn[uid]; ok {
                            conn.Send(gop.GetBin())
                        }
                    }
                } else {
                    if sid := gop.GetSid(); sid != 0 {
                        this.Broadcast(sid, gop.GetBin())
                    }
                }
            }
    }
}

func (this *GateServer) Logout(conn *ClientConnection) {
    h := this.conn2gheader[conn]
    uid, sid := h.GetUid(), h.GetSid()
    conns := this.sid2conns[sid]
    for i, c := range conns {
        if c == conn {
            conns[i] = conns[len(conns)-1]
            conns = conns[:len(conns)-1]
        }
    }
    this.sid2conns[sid] = conns
    delete(this.conn2gheader, conn)
    
    _, exist := this.uid2conn[uid] 
    delete(this.uid2conn, uid)
    if uid != 0 && exist {
        this.GateEntry <- &proto.GateInPack{Header: h}
    }
}

func (this *GateServer) Login(conn *ClientConnection, m pb.Message) *proto.GateInHeader{
    // check token
    req := m.(*proto.C2SLogin)
    uid := req.GetUid()
    sid := req.GetChannel()
    // register 
    if _, exist := this.uid2conn[uid]; exist { return nil }
    this.uid2conn[uid] = conn
    fmt.Println("[CCU]", len(this.uid2conn))
    if conns, exist := this.sid2conns[sid]; exist {
        this.sid2conns[sid] = append(conns, conn)
    } else {
        conns := make([]*ClientConnection, 0, 10)
        conns = append(conns, conn)
        this.sid2conns[sid] = conns
    }
    gheader := &proto.GateInHeader{Uid: pb.Uint32(uid), Sid: pb.Uint32(sid)}
    this.conn2gheader[conn] = gheader
    return gheader
}

func (this *GateServer) Broadcast(sid uint32, bin []byte) {
    if conns, ok := this.sid2conns[sid]; ok {
        for _, conn := range conns {
            conn.Send(bin)
        }
    }
}


type ConnBuff struct {
    conn    *ClientConnection
    buff    []byte
}


