package network

import (
    "net"
    "fmt"
    "time"
)

const (
    XML_REP1 = `
<?xml version="1.0"?>
<cross-domain-policy>
    <allow-access-from domain="*" to-ports="*"/>
</cross-domain-policy>
`
)

type AuthServer struct {
}

func (aus *AuthServer) Start() {
    ln, err := net.Listen("tcp", ":13830")
    if err != nil {
        fmt.Println("authServer err", err)
    }
    fmt.Println("authServer runing")
    for {
        conn, err := ln.Accept()
        if err != nil {
            continue
        }
        go func(c net.Conn) {
            c.Write([]byte(XML_REP1))
            c.Write([]byte("\x00"))
            time.Sleep(time.Second)
            c.Close()
        }(conn)
    }
}
