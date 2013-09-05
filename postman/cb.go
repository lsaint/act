package postman

import (
    "fmt"
    "net/http"
    "io/ioutil"
    "net/url"

    pb "code.google.com/p/goprotobuf/proto"

    "act/proto"
)

type HttpCb struct {
    GiftCbChan    chan *proto.GiftCbPack
}

func NewHttpCb() *HttpCb {
    return &HttpCb{make(chan *proto.GiftCbPack, 128)}
}

func (this *HttpCb) Start() {
    http.HandleFunc("/giftcb", func(w http.ResponseWriter, r *http.Request) {
            this.giftCb(w, r)
    })

    fmt.Println("gift callback runing")
    http.ListenAndServe(":13902", nil)
}

func (this *HttpCb) giftCb(w http.ResponseWriter, r *http.Request) {
    err_ret := "op_ret=-10"

    recv_post, err := ioutil.ReadAll(r.Body)
    if err != nil {
        fmt.Fprint(w, err_ret)
        return
    }
    //fmt.Println("recv_post", string(recv_post))

    ret_m, err1 := url.ParseQuery(string(recv_post))
    if err1 != nil || len(ret_m) == 0 {
        fmt.Fprint(w, err_ret)
        return
    }

    if len(ret_m) == 11 {
        pack := &proto.GiftCbPack{
                    Op: pb.String(ret_m["op_ret"][0]),
                    Sid: pb.String(ret_m["chn"][0]),
                    FromUid: pb.String(ret_m["fromuid"][0]),
                    ToUid: pb.String(ret_m["touid"][0]),
                    GiftId: pb.String(ret_m["giftid"][0]),
                    GiftCount: pb.String(ret_m["giftcount"][0]),
                    OrderId: pb.String(ret_m["orderid"][0]),
        }
        this.GiftCbChan <- pack
        fmt.Fprint(w, "op_ret=1")
    }
}
