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

    sal_recv_chan := make(chan *proto.SalPack)
    sal_send_chan := make(chan *proto.SalPack)
    sal_bakend := network.NewSalBackend(sal_recv_chan, sal_send_chan)
    go sal_bakend.Start()
    sal_server := network.NewSalServer(sal_recv_chan, sal_send_chan)
    go sal_server.Start()
    
    luaMgr := script.NewLuaMgr()

    gs := network.NewGateServer(luaMgr)
    go gs.Start()

    handleSig()
}

