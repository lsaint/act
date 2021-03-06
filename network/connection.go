package network

import (
    "fmt"
    "net"
    "bufio"
    "encoding/binary"
    "time"

)

const (
    XML_REP = `<?xml version="1.0"?><cross-domain-policy><allow-access-from domain="*" to-ports="*"/></cross-domain-policy>`

    LEN_HEAD    =   2
    LEN_URI     =   2
    MAX_LEN_HEAD   = 1024 * 4
)

type ClientConnection struct {
    conn        net.Conn
    reader      *bufio.Reader
    writer      *bufio.Writer
    sendchan    chan []byte
}

func NewClientConnection(c net.Conn) *ClientConnection {
    cliConn := new(ClientConnection)
    cliConn.conn = c
    cliConn.reader = bufio.NewReader(c)
    cliConn.writer = bufio.NewWriter(c)
    cliConn.sendchan = make(chan []byte, 64)
    return cliConn
}

func (this *ClientConnection) Send(buf []byte) {
    head := make([]byte, LEN_HEAD)
    binary.LittleEndian.PutUint16(head, uint16(len(buf)))
    buf = append(head, buf...)

    select {
        case this.sendchan <- buf:

        default:
            //fmt.Println("send chan overflow or closed")
    }
}

func (this *ClientConnection) sendall() bool {
    for more := true; more; {
        select {
            case b := <-this.sendchan:
                if _, err := this.writer.Write(b); err != nil {
                    fmt.Println("write err:", err)
                    return false
                }
            default:
                more = false
        }
    }

    if err := this.writer.Flush(); err != nil {
        fmt.Println("flush err:", err)
        return false
    }
    return true
}

func (this *ClientConnection) duplexRead(buff []byte) bool {
    var read_size int
    for {
        // write
        if !this.sendall() {
            break
        }

        // read
        this.conn.SetReadDeadline(time.Now().Add(1e8))
        n, err := this.reader.Read(buff[read_size:])
        if err != nil {
            if e, ok := err.(*net.OpError); ok && e.Temporary() {
                read_size = n
                continue
            } else {
                //fmt.Println("read err disconnect:", err)
                break
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
    buff_head := make([]byte, LEN_HEAD)
    if !this.duplexRead(buff_head) {
        return
    }
    len_head := binary.LittleEndian.Uint16(buff_head)
    if len_head > MAX_LEN_HEAD {
        if len_head == 17735 {
            this.WriteFlashAuthRep()
        } else {
            fmt.Println("message len too long", len_head, string(buff_head))
        }
        return
    }
    ret = make([]byte, len_head)
    if !this.duplexRead(ret) {
        return
    }
    ok = true
    return
}

func (this *ClientConnection) WriteFlashAuthRep() {
    this.writer.Write([]byte(XML_REP))
    this.writer.Write([]byte("\x00"))
    this.writer.Flush()
}

