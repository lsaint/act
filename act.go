// L'act

package main

import (
    "fmt"
    "os"
    "syscall"
    "os/signal"
    "runtime"
    //"net/http"
    //"log"
    //_ "net/http/pprof"

    "act/script"
    "act/network"
    "act/proto"
)


func handleSig() {
    c := make(chan os.Signal, 1)
    signal.Notify(c, os.Interrupt, syscall.SIGTERM)

    for sig := range c {
        fmt.Println("__handle__signal__", sig)
        return
    }
}


func main() {
    runtime.GOMAXPROCS(runtime.NumCPU())

    //go func() {
    //    log.Println(http.ListenAndServe("localhost:6061", nil))
    //}()

    //authServer := network.AuthServer{}
    //go authServer.Start()

    salSendChan := make(chan *proto.SalPack, 1024)
    salRecvChan := make(chan *proto.SalPack, 1024)

    luaMgr := script.NewLuaMgr()

    gs := network.NewGateServer(luaMgr, salRecvChan, salSendChan)
    go gs.Start()

    agent := network.NewSalAgent(salRecvChan, salSendChan)
    go agent.ReadFromSalProxy()

    handleSig()
}

