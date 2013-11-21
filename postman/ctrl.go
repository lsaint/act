package postman

import (
    "fmt"
    "time"
    "io/ioutil"
    "net/http"
)

type NetCtrl struct {
    CtrlChan        chan string
}

func NewNetCtrl() *NetCtrl {
    return &NetCtrl{make(chan string, 64)}
}

func (this *NetCtrl) Start() {
    http.HandleFunc("/ctrl", func(w http.ResponseWriter, r *http.Request) {
            this.ctrl(w, r)
    })

    fmt.Println("net ctrl runing")
    http.ListenAndServe(":31121", nil)
}

func (this *NetCtrl) ctrl(w http.ResponseWriter, r *http.Request) {
    err_ret, ret := "X", "√"

    recv_post, err := ioutil.ReadAll(r.Body)
    if err != nil {
        fmt.Fprint(w, err_ret)
        return
    }
    req := string(recv_post)
    fmt.Println("[CTRL]", req)
    select {
        case this.CtrlChan <- req:

        case <-time.After(30 * time.Second):
            ret = "timeout"
    }

    fmt.Fprint(w, ret)
}

