package network


import (
    "fmt"
    "net"
    "bytes"
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
    uid2buffer  map[uint32]*bytes.Buffer
    
    salRecvChan   chan *proto.SalPack
    salSendChan   chan *proto.SalPack

    clientBuffChan  chan *ClientBuff
}


func NewSalAgent(salSendChan  chan *proto.SalPack,
                    clientBuffChan chan *ClientBuff) *SalAgent {
    conn, err := net.Dial("tcp", SAL_FRONTEND)
    if err != nil {
        panic("connect to sal front end err")
    }
    fmt.Println("connect to sal frontend sucess")
    return &SalAgent{cc: NewClientConnection(conn),
                uid2buffer: make(map[uint32]*bytes.Buffer),
                buffChan: make(chan []byte, 1024),
                salSendChan: salSendChan,
                salRecvChan: make(chan *proto.SalPack, 1024)}
}

func (this *SalAgent) ReadFromSal() {
    fmt.Println("sal agent running")
    for {
        if buff, ok := this.cc.duplexReadBody(); ok {
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

func (this *SalAgent) processSalRecvChan() {
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
            // only process single user's msg
            // no situation for client broadcast to server
            fmt.Println("client broadcast server err", sid)
            continue
        }
        buffer.Write(pack.GetBin())

        if buffer.Len() < LEN_HEAD { continue }
        length := int(binary.LittleEndian.Uint16(buffer.Bytes()[:LEN_HEAD]))
        if length < buffer.Len() { 
            buffer.Next(LEN_HEAD)
            client_buff := &ClientBuff{uids[0], sid, buffer.Next(length)}
            // send to gate
            this.clientBuffChan <- client_buff
        }
    }
}

func (this *SalAgent) doSend() {
    for pack := range this.salSendChan {
        if data, err := pb.Marshal(pack); err == nil {
            uri_field := make([]byte, LEN_URI)
            binary.LittleEndian.PutUint32(uri_field, uint32(URI_TRANSPORT))
            data = append(data, uri_field...)
            this.cc.Send(data)
        }
    }
}


