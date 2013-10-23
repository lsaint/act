# -*- coding: utf-8 -*-

import random, json, time
from datetime import datetime

from pymongo import MongoClient


execfile("../conf/config.txt")
client = MongoClient(MONGO_SRV, 27017)
db = client.act
db.authenticate(MONGO_USR, MONGO_PSW)


def T():
    return time.strftime("%Y/%m/%d %H:%M:%S")


### 


def randomMotion(**kwargs):
    count = kwargs["count"]
    pos = random.sample(range(db.motion.count()), count)
    ret = []
    for p in pos:
        ret.append(db.motion.find({}, {"_id": 0}).skip(p).limit(1).next())
    return ret, None


def randomPunish(**kwargs):
    count = kwargs["count"]
    pos = random.sample(range(db.punish.count()), count)
    ret = []
    for p in pos:
        ret.append(db.punish.find({}, {"_id": 0}).skip(p).limit(1).next())
    for i in range(count):
        ret[i]["_id"] = str(i+1)
    return ret, None


#time=0 : ingore,   time=1 : now
def saveGift(**kwargs):
    if kwargs.get("create_time") == 1:
        kwargs["create_time"] = datetime.now()
    if kwargs.get("finish_time") == 1:
        kwargs["finish_time"] = datetime.now()
    db.gift.update({"orderid": kwargs["orderid"]}, {"$set": kwargs}, upsert=True)
    return {}, None


def saveRoundSidInfo(**kwargs):
    kwargs["time"] = T()
    db.rank_sid.insert(kwargs)
    return {}, None


def saveRoundUidInfo(**kwargs):
    kwargs["time"] = T()
    db.rank_uid.insert(kwargs)
    return {}, None


