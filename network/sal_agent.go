package network


import (
    "fmt"
    "net"
    //"bytes"
    "encoding/binary"

    pb "code.google.com/p/goprotobuf/proto" 

    "act/proto"
)

const (
    SAL_FRONTEND    = "127.0.0.1:3929"
    URI_REGISTER    = 1
    URI_TRANSPORT   = 2
)


type SalAgent   struct {
    cc      *ClientConnection
    buffChan    chan []byte
    salRecvChan   chan *proto.SalPack
    salSendChan   chan *proto.SalPack
}


func NewSalAgent(salRecvChan, salSendChan  chan *proto.SalPack) *SalAgent {
    conn, err := net.Dial("tcp", SAL_FRONTEND)
    if err != nil {
        panic("connect to sal front end err")
    }
    fmt.Println("connect to sal frontend sucess")
    agent := &SalAgent{cc: NewClientConnection(conn),
                buffChan: make(chan []byte, 1024),
                salSendChan: salSendChan,
                salRecvChan: salRecvChan}
    agent.registerAgent()
    go agent.doRecv()
    go agent.doSend()
    return agent
}

func (this *SalAgent) registerAgent() {
    reg := make([]byte, LEN_URI)
    binary.LittleEndian.PutUint16(reg, uint16(URI_REGISTER))
    this.cc.Send(reg)    
}

func (this *SalAgent) ReadFromSalProxy() {
    fmt.Println("sal agent running")
    for {
        if buff, ok := this.cc.duplexReadBody(); ok {
            fmt.Println("read from sal proxy", len(buff))
            this.buffChan <- buff
        } else {
            panic("disconnect from sal frontend")
        }
    }
}

func (this *SalAgent) doRecv() {
    for msg := range this.buffChan {
        msg = msg[LEN_URI:] // skip uri
        sal_pack := &proto.SalPack{}
        if err := pb.Unmarshal(msg, sal_pack); err != nil { 
            fmt.Println("pb Unmarshal err", err)
            continue
        }
        this.salRecvChan <- sal_pack
    }
}

func (this *SalAgent) doSend() {
    for pack := range this.salSendChan {
        if data, err := pb.Marshal(pack); err == nil {
            uri_field := make([]byte, LEN_URI)
            binary.LittleEndian.PutUint16(uri_field, uint16(URI_TRANSPORT))
            data = append(uri_field, data...)
            fmt.Println("send to sal proxy", len(data))
            this.cc.Send(data)
        }
    }
}


