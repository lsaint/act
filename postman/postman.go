package postman


import (
    "fmt"
    "strings"
    "net/http"
    "io/ioutil"
)

type PostRequest struct {
    Request         string
    Ret             chan string
}

type Postman struct {
    RequestChan         chan *PostRequest
}


func NewPostman()  *Postman {
    pm := &Postman{make(chan *PostRequest, 128)}
    go pm.loop()
    return pm
}


func (this *Postman) loop() {
    for {
        select {
            case req := <-this.RequestChan:
               this.post(req) 
        }
    }
}

func (this *Postman) post(req *PostRequest) {
    url := "http://127.0.0.1:8080/rpc"    
    b := strings.NewReader(req.Request)
    fmt.Println("post-", req.Request, len(req.Request))
    http_req, err := http.Post(url, "application/json", b)
    if err == nil {
        if body, e := ioutil.ReadAll(http_req.Body); e == nil {
            req.Ret <- string(body)
        } else {
            fmt.Println("http post ret err:", e)
        }
        http_req.Body.Close()
    } else {
        close(req.Ret)
    }
}

func (this *Postman) Post(s string) string {
    req := &PostRequest{s, make(chan string, 1)}
    this.post(req)
    return <-req.Ret
}

