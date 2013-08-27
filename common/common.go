package common

import (
    pb "code.google.com/p/goprotobuf/proto"
)

type RoomInPack struct {
    Uid         uint32
    PName       string
    Request     pb.Message
}

type RoomOutPack struct {
    Sid         uint32
    Uids        []uint32
    Msg         pb.Message
}

