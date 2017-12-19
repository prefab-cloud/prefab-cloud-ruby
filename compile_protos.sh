#!/usr/bin/env bash
grpc_tools_ruby_protoc -I ../prefab-cloud/ --ruby_out=lib --grpc_out=lib prefab.proto
