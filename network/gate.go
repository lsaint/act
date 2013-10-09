package network

import (
    "fmt"
    "bytes"
    "encoding/binary"

    pb "code.google.com/p/goprotobuf/proto"

    "act/proto"
)
type GateSendRecver interface {
    Start(out chan *proto.GateOutPack, in chan *proto.GateInPack)
}


type ClientBuff struct {
    Uid         uint32    
    Sid         uint32
    Bin         []byte
}



type GateServer struct {
    clientBuffChan  chan *ClientBuff
    GateEntry       chan *proto.GateInPack
    GateExit        chan *proto.GateOutPack
    uid2buffer      map[uint32]*bytes.Buffer
    salSendChan     chan *proto.SalPack
}

func NewGateServer(sendrecver GateSendRecver, 
                    clientBuffChan chan *ClientBuff,
                    salSendChan chan *proto.SalPack) *GateServer {
    gs := &GateServer{clientBuffChan: clientBuffChan,
                        salSendChan: salSendChan,
                        uid2buffer: make(map[uint32]*bytes.Buffer),
                        GateEntry: make(chan *proto.GateInPack, 1024),
                        GateExit: make(chan *proto.GateOutPack, 1024)}
    go sendrecver.Start(gs.GateExit, gs.GateEntry)
    return gs
}

func (this *GateServer) Start() {
    fmt.Println("gate server running")
    go this.processClientBuff()
    go this.processGateExit()
}

func (this *GateServer) processClientBuff() {
    for { select {
        case client_buff := <-this.clientBuffChan:
            uid := client_buff.Uid
            var buffer *bytes.Buffer
            buffer = this.uid2buffer[uid]
            if buffer == nil {
                this.uid2buffer[uid] = new(bytes.Buffer)
            }
            buffer.Write(client_buff.Bin)
            if buffer.Len() < LEN_HEAD { continue }
            length := int(binary.LittleEndian.Uint16(buffer.Bytes()[:LEN_HEAD]))
            if length > buffer.Len() + LEN_HEAD { continue }

            buffer.Next(LEN_HEAD)
            body := buffer.Next(length)
            uri := binary.LittleEndian.Uint32(body[:LEN_URI])
            gheader := &proto.GateInHeader{Uid:pb.Uint32(client_buff.Uid), 
                                            Sid: pb.Uint32(client_buff.Sid)}
            this.GateEntry <-&proto.GateInPack{Header: gheader, 
                                        Uri: pb.Uint32(uri), Bin: body[LEN_URI:]}
    }}
}

func (this *GateServer) processGateExit() {
    for { select {
        case gop := <-this.GateExit :
            data := make([]byte, LEN_HEAD)
            bin := gop.GetBin()
            binary.LittleEndian.PutUint16(data, uint16(len(bin)))
            data = append(data, bin...)
            pack := &proto.SalPack{Sid: gop.Sid, Uids: gop.Uids, Bin: data}
            this.salSendChan <- pack
     }}
}

