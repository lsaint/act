# -*- coding: utf-8 -*-

import random, json, time

from pymongo import MongoClient


client = MongoClient("localhost", 27017)
db = client.act
db.authenticate("lsaint", "111333")


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
    return ret, None


def count(**kwargs):
    database = kwargs["db"]
    return {"count": getattr(db, database).count()}, None


def slice(**kwargs):
    database = kwargs["db"]
    ret = getattr(db, database).find().skip(kwargs["offset"]).limit(kwargs["limit"])
    return list(ret), None



