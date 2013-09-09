# -*- coding: utf-8 -*-

import json, time 
from gevent import wsgi

from bson.objectid import ObjectId

import dbcore

class JSONEncoder(json.JSONEncoder):
    def default(self, o):
        if isinstance(o, ObjectId):
            return str(o)
        return json.JSONEncoder.default(self, o)


def handle(environ, start_response):
    if environ['REQUEST_METHOD'] != 'POST':
        start_response('404 Not Found', [('Content-Type', 'text/html')])
        return ["L'"]
    content_length = int(environ["CONTENT_LENGTH"])
    # fetch the request body
    request = environ["wsgi.input"].read(content_length)
    print "request:", request
    jn = json.loads(request)
    ret = "{}"
    if type(jn) == dict:
        ret = dispatch(jn)
    start_response('200 OK', [('Content-Type', 'application/json')])
    return ret


def dispatch(jn):
    print dbcore.T(), "req", jn
    t = time.time()
    kwargs = jn["params"][0]
    method = getattr(dbcore, jn["method"])
    reply, err = method(**kwargs)
    jn = {"result":reply, "error":err, "id":jn["id"]}
    print "reply", jn, "[TIME]", time.time() - t
    return JSONEncoder().encode(jn)


if __name__ == "__main__":
    server = wsgi.WSGIServer(('', 8081), handle)
    print("starting act db server on port 8081")
    server.serve_forever()

