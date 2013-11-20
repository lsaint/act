# -*- coding: utf-8 -*-

import random, json, time
from datetime import datetime, timedelta

import gevent
from pymongo import MongoClient


execfile("../conf/config.txt")
client = MongoClient(MONGO_SRV, 27017)
db = client.act
db.authenticate(MONGO_USR, MONGO_PSW)


def T():
    return time.strftime("%Y/%m/%d %H:%M:%S")

g_uid2name = {}
def cacheName():
    global g_uid2name
    ret = db.uname.find()
    for q in ret:
        g_uid2name[q["uid"]] = q["name"]
cacheName()

### 

def setName(**kwargs):
    global g_uid2name, g_updateName
    uid = kwargs["uid"]
    name = kwargs["name"]
    g_uid2name[uid] = name
    g_updateName[uid] = name
    return {}, None


g_updateName = {}
def updateSetName():
    global g_updateName
    while True:
        gevent.sleep(3)
        if len(g_uid2name) == 0:
            continue
        uids = []
        new_items = []
        for u, n in g_updateName.iteritems():
            uids.append(u)
            new_items.append({"uid": u, "name": n, "time": datetime.now()})
        if len(uids) > 0:
            db.uname.remove({"uid": {"$in" :uids}})
            db.uname.insert(new_items)
            g_updateName = {}


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


def getBillboard(**kwargs):
    count, sid = kwargs["count"], kwargs["sid"]
    today = datetime.today()
    monday = today - timedelta(days=(datetime.isoweekday(today)-1),
                        hours=today.hour, minutes=today.minute, seconds=today.second)
    ret = db.gift.aggregate([{"$match": {"sid": sid, "step": 3, "create_time": {"$gt": monday}}},
                           {"$group": {"_id": "$uid", "total": {"$sum": "$money"}}},
                           {"$sort": {"total": -1}},
                           {"$limit": count}])
    if ret["ok"] != 1:
        return {}, None
    r = {}
    for item in ret["result"]:
        total, uid = item["total"], item["_id"]
        name = g_uid2name.get(uid) or str(uid)
        r[name] = total
    return r, None

