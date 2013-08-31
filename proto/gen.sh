protoc --go_out=. server.proto
protoc --go_out=. client.proto
protoc --python_out=../ client.proto
