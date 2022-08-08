#! /usr/bin/env bash

PREFAB_CDN_URL="https://api-prefab-cloud.global.ssl.fastly.net" \
  PREFAB_LOG_CLIENT_BOOTSTRAP_LOG_LEVEL=debug \
  PREFAB_CLOUD_HTTP=true \
  PREFAB_API_KEY="1|local_development_api_key" \
  PREFAB_GRPC_URL="localhost:50051" \
  ruby -Ilib test/harness_server.rb
