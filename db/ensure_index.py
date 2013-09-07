# -*- coding: utf-8 -*-

from pymongo import MongoClient

db = MongoClient("localhost", 27017).act
name = raw_input("name: ")
pw   = raw_input("pw: ")
db.authenticate(name, pw)

print db.punish.ensure_index("desc")
print db.motion.ensure_index("desc")
print db.gift.ensure_index("orderid")

