#!/usr/bin/env bash

set -e

PROTO_ROOT="${PROTO_ROOT:-..}"

gem install grpc-tools

(
  cd "$PROTO_ROOT/prefab-cloud"
  git pull --rebase
)

grpc_tools_ruby_protoc -I "$PROTO_ROOT/prefab-cloud/" --ruby_out=lib --grpc_out=lib prefab.proto

gsed -i 's/^module Prefab$/module PrefabProto/g' lib/prefab_pb.rb

# on M1 you need to
# 1. run in rosetta
# 2. mv gems/2.6.0/gems/grpc-tools-1.43.1/bin/x86_64-macos x86-macos
