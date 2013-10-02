package network


import (
    "fmt"
    "net"
    "bytes"
    "bufio"

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
    uid2buffer  map[uint32]*bytes.Buffer
    sid2buffer  map[uint32]*bytes.Buffer
    salSendChan   chan *proto.SalPack
    salRecvChan   chan *proto.Salpack
}


func NewSalAgent() *SalAgent {
    conn, err := net.Dial("tcp", SAL_FRONTEND)
    if err != nil {
        panic("connect to sal front end err", err)
    }
    return &SalAgent{cc: NewClientConnection(conn),
                uid2buffer: make(map[uint32]*bytes.Buffer),
                sid2buffer: make(map[uint32]*bytes.Buffer),
                buffChan: make(chan []byte, 1024),
                salSendChan: make(chan *proto.SalPack, 1024),
                salRecvChan: make(chan *proto.SalPack, 1024)}
}

func (this *SalAgent) readFromSal() {
    for {
        if buff, ok := this.cc.duplexReadBody(); ok {
            this.buffChan <- buff
            fmt.Println("read sal msg err", err)
            break
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

func (this *SalAgent) parseSalPack() {
    for pack := range this.salRecvChan {
        uids := pack.GetUids()
        sid  := pack.GetSid()
        var buffer *bytes.Buffer
        if len(uids) != 0 {
            uid := uids[0]
            buffer =  this.uid2buffer[uid]
            if buffer == nil {
                this.uid2buffer[uid] = new(bytes.Buffer)
            }
        } else {
            buffer = this.sid2buffer[sid]
            if buffer == nil {
                this.sid2buffer[sid] = new(bytes.Buffer)
            }
        }
        buffer.Write(pack.GetBin())

        if buffer.Len() < LEN_HEAD { continue }
        length := binary.LittleEndian.Uint16(head[:LEN_HEAD])
        if length < buffer.Len() { 
            // send to gate server's buff chan
        }
    }
}

func (this *SalAgent) parseBuffer() {
    head := make([]byte, LEN_HEAD)
    var length uint16
    for buff := range this.buffChan {
        if _, err := this.buffer.Write(buff); err != nil {
            fmt.Println("buffer write err", err)
        }

        // parse
        if this.buffer.Len() < LEN_HEAD { continue }
        this.buffer.Read(head)
        length := binary.LittleEndian.Uint16(head)
    }
}

func (this *SalAgent) doSend() {
    for pack := range this.salSendChan {
        
    }
}


