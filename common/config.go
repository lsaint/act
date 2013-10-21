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
}

func NewConfig() *Config {
    ls := &Config{L: lua.NewState()}
    ls.ReadConfig()
    return ls
}

func (this *Config) ReadConfig() {
    err := this.L.DoFile("./conf/config.txt")
    if err != nil {
        fmt.Println(err)
        panic("read config err")
    }
}

func (this *Config) GetMaxState() uint32 {
    this.L.GetGlobal("MAX_STATE")
    count := this.L.ToInteger(-1)
    return uint32(count)
}
