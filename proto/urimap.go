package proto

import (
    "reflect"
)

type Uri2Proto map[uint16]reflect.Type

var URI2PROTO Uri2Proto = Uri2Proto {
    0       :   reflect.TypeOf(C2SLogout{}),
    1       :   reflect.TypeOf(C2SLogin{}),
    2       :   reflect.TypeOf(C2SPrelude{}),
    3       :   reflect.TypeOf(C2SChat{}),
    4       :   reflect.TypeOf(C2SPoll{}),
    5       :   reflect.TypeOf(C2SPunishOver{}),
    6       :   reflect.TypeOf(C2SStopGame{}),
    7       :   reflect.TypeOf(C2SRegGift{}),
    8       :   reflect.TypeOf(C2SChangeMode{}),
    37      :   reflect.TypeOf(C2SPing{}),
}


type Proto2Uri map[reflect.Type]uint16
var PROTO2URI Proto2Uri

func init() {
    PROTO2URI = make(map[reflect.Type]uint16)
    for uri, proto_type := range URI2PROTO {
        PROTO2URI[proto_type] = uri
    }
}

