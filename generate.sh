#!/usr/bin/env bash
grpc_tools_ruby_protoc -I /Users/jeffdwyer/Documents/workspace/RateLimitInc/ratelimit-java/src/main/proto --ruby_out=lib/prefab --grpc_out=lib/prefab ratelimit.proto prefab.proto
