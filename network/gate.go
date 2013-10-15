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



type GateServer struct {
    GateEntry       chan *proto.GateInPack
    GateExit        chan *proto.GateOutPack
    uid2buffer      map[uint32]*bytes.Buffer
    salSendChan     chan *proto.SalPack
    salRecvChan     chan *proto.SalPack
}

func NewGateServer(sendrecver GateSendRecver, 
                    salRecvChan, salSendChan chan *proto.SalPack) *GateServer {
    gs := &GateServer{ salRecvChan: salRecvChan,
                        salSendChan: salSendChan,
                        uid2buffer: make(map[uint32]*bytes.Buffer),
                        GateEntry: make(chan *proto.GateInPack, 1024),
                        GateExit: make(chan *proto.GateOutPack, 1024)}
    go sendrecver.Start(gs.GateExit, gs.GateEntry)
    return gs
}

func (this *GateServer) Start() {
    fmt.Println("gate server running")
    go this.processSalRecvChan()
    go this.processGateExit()
}

func (this *GateServer) processSalRecvChan() {
    for { select {
        case pack := <-this.salRecvChan:
            uids := pack.GetUids()
            sid  := pack.GetSid()
            var buffer *bytes.Buffer
            if len(uids) != 0 {
                uid := uids[0]
                buffer =  this.uid2buffer[uid]
                if buffer == nil {
                    buffer = new(bytes.Buffer)
                    this.uid2buffer[uid] = buffer
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
            if length > buffer.Len() { continue }

            buffer.Next(LEN_HEAD)
            body := make([]byte, length)
            buffer.Read(body)
            uri := binary.LittleEndian.Uint16(body[:LEN_URI])
            gheader := &proto.GateInHeader{Uid:pb.Uint32(uids[0]), Sid: pb.Uint32(sid)}
            this.GateEntry <-&proto.GateInPack{Header: gheader, 
                                        Uri: pb.Uint32(uint32(uri)), Bin: body[LEN_URI:]}
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

