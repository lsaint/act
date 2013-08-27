package network

import (
    "net"
    "fmt"

    "act/common"
)

type AuthServer struct {
}

func (aus *AuthServer) Start() {
    ln, err := net.Listen("tcp", ":23803")
    if err != nil {
        fmt.Println("authServer err")
    }
    fmt.Println("authServer runing")
    for {
        conn, err := ln.Accept()
        if err != nil {
            continue
        }
        go func(c net.Conn) {
            c.Write([]byte(common.XML_REP))
            c.Write([]byte("\x00"))
            c.Close()
        }(conn)
    }
}
