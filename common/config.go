package common

import (
    "fmt"
    "github.com/aarzilli/golua/lua"
)

var CF *Config
func init() {
    CF  =   NewConfig()
}

type Config struct {
    L       *lua.State

    MaxState    uint32
}

func NewConfig() *Config {
    ls := lua.NewState()
    cf := &Config{L: ls}
    cf.ReadConfig()

    ls.GetGlobal("MAX_STATE")
    cf.MaxState = uint32(ls.ToInteger(-1))

    return cf
}

func (this *Config) ReadConfig() {
    err := this.L.DoFile("./conf/config.txt")
    if err != nil {
        fmt.Println(err)
        panic("read config err")
    }
}
