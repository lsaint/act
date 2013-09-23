package network

import (
    "fmt"
    "net"
    "bufio"
    "encoding/binary"
    "time"

)

const (
    ConnStateIn    = iota
    ConnStateDisc  = iota

    MAX_LEN_HEAD   = 1024 * 4
)

type ClientConnection struct {
    conn        net.Conn
    reader      *bufio.Reader
    writer      *bufio.Writer
    connState   int
}

func NewClientConnection(c net.Conn) *ClientConnection {
    cliConn := new(ClientConnection)
    cliConn.conn = c
    cliConn.reader = bufio.NewReader(c)
    cliConn.writer = bufio.NewWriter(c)
    return cliConn
}

func (this *ClientConnection) Send(buf []byte) {
    if this.connState == ConnStateDisc { return }

    head := make([]byte, 4)
    binary.LittleEndian.PutUint32(head, uint32(len(buf)))
    buf = append(head, buf...)

    this.writer.Write(buf)
}

//func (this *ClientConnection) blockSend(b []byte) bool {
//    for len(b) > 0 {
//        n, err := this.conn.Write(b)
//        if err == nil {
//            b = b[n:]
//        } else if e, ok := err.(*net.OpError); ok && e.Temporary() {
//            continue
//        } else {
//            if this.connState != ConnStateDisc {
//                this.connState = ConnStateDisc
//            }
//            fmt.Println("blockSend disconnect")
//            return false
//        }
//    }
//    return true
//}

func (this *ClientConnection) sendall() bool {
    if err := this.writer.Flush(); err != nil {
        if this.connState != ConnStateDisc {
            this.connState = ConnStateDisc
        }
        fmt.Println("send err:", err)
        return false
    }
    return true
}

func (this *ClientConnection) duplexRead(buff []byte) bool {
    var read_size int
    for {
        // write
        if !this.sendall() {
            return false
        }

        // read
        this.conn.SetReadDeadline(time.Now().Add(1e8))
        n, err := this.reader.Read(buff[read_size:])
        if err != nil {
            if e, ok := err.(*net.OpError); ok && e.Temporary() {
                read_size = n
                continue
            } else {
                //fmt.Println("read err, disconnect", err)
                return false
            }
        }

        if n == 0 { return true }
        if n < len(buff) {
            read_size += n
            continue
        }
        return true
    }
    return false
}

func (this *ClientConnection) duplexReadBody() (ret []byte,  ok bool) {
    buff_head := make([]byte, 4)
    if !this.duplexRead(buff_head) {
        return
    }
    len_head := binary.LittleEndian.Uint32(buff_head)
    if len_head > MAX_LEN_HEAD {
        fmt.Println("message len too long", len_head)
        return
    }
    ret = make([]byte, len_head)
    if !this.duplexRead(ret) {
        return
    }
    ok = true
    return
}

func (this *ClientConnection) Close() {
    this.connState  = ConnStateDisc 
    this.conn.Close()
}

func (this* ClientConnection) IsClose() bool {
    return this.connState == ConnStateDisc
}
