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

    authServer := network.AuthServer{}
    go authServer.Start()
    
    luaMgr := script.NewLuaMgr()

    gs := network.NewGateServer(luaMgr)
    go gs.Start()

    handleSig()
}

