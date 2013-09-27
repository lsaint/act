package network

import (
    "fmt"
    "net"
    "encoding/binary"

    pb "code.google.com/p/goprotobuf/proto"

    "act/proto"
)

const (
    URI_REGISTER        = 1
    URI_TRANSPORT       = 2
    URI_UNREGISTER      = 3
)


type SalBackend struct {
    buffChan        chan *ConnBuff
    sid2conn        map[uint32]*ClientConnection
    conn2sid        map[*ClientConnection]uint32
    SalEntry        chan *proto.SalPack
    SalExit         chan *proto.SalPack
}

func NewSalBackend(entry, exit chan *proto.SalPack) *SalBackend {
    gs := &SalBackend{buffChan: make(chan *ConnBuff),
                    sid2conn: make(map[uint32]*ClientConnection),
                    conn2sid: make(map[*ClientConnection]uint32),
                    SalEntry: entry,
                    SalExit:  exit}
    go gs.parse()
    return gs
}


func (this *SalBackend) Start() {
    ln, err := net.Listen("tcp", ":13927")                                                                            
    if err != nil {
        fmt.Println("Listen err", err)
        return
    }
    fmt.Println("SalBackend runing")
    for {
        conn, err := ln.Accept()
        if err != nil {
            fmt.Println("Accept error", err)
            continue
        }
        go this.acceptConn(conn)
    }
}

func (this *SalBackend) acceptConn(conn net.Conn) {
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

func (this *SalBackend) parse() {
    for {
        select {
            case conn_buff := <-this.buffChan :
                msg := conn_buff.buff
                conn := conn_buff.conn

                if msg == nil {
                    this.unregister(conn)
                    continue
                }

                uri := binary.LittleEndian.Uint32(msg[:4])
                switch uri {
                case 1:
                    this.register(msg[4:], conn)
                case 2:
                    this.comein(msg[4:])
                default:
                    this.unregister(conn)
                }

            case pack := <-this.SalExit :
                this.comeout(pack)
        }
    }
}

func (this *SalBackend) unpack(b []byte) (msg *proto.SalPack, err error) {
    msg = &proto.SalPack{}
    if err = pb.Unmarshal(b, msg); err != nil {
        fmt.Println("pb Unmarshal", err)
    }
    return
}

func (this *SalBackend) comein(b []byte) {
    if msg, err := this.unpack(b); err == nil {
        this.SalEntry <- msg
    }
}

func (this *SalBackend) comeout(pack *proto.SalPack) {
    conn, exist := this.sid2conn[pack.GetSid()]
    if !exist {
        return
    }
    if data, err := pb.Marshal(pack); err == nil {
        uri_field := make([]byte, 4)
        binary.LittleEndian.PutUint32(uri_field, uint32(URI_TRANSPORT))
        data = append(data, uri_field...)
        conn.Send(data)
    }
}

func (this *SalBackend) register(b []byte, cc *ClientConnection) {
    if msg, err := this.unpack(b); err == nil {
        sid := msg.GetSid()    
        this.sid2conn[sid] = cc
        this.conn2sid[cc] = sid
    }
}

func (this *SalBackend) unregister(cc *ClientConnection) {
    sid := this.conn2sid[cc]
    delete(this.sid2conn, sid)
    delete(this.conn2sid, cc)
}

//type ConnBuff struct {
//    conn    *ClientConnection
//    buff    []byte
//}


