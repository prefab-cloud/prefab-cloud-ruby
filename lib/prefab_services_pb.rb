# Generated by the protocol buffer compiler.  DO NOT EDIT!
# Source: prefab.proto for package 'prefab'

require 'grpc'
require 'prefab_pb'

module Prefab
  module RateLimitService
    class Service

      include GRPC::GenericService

      self.marshal_class_method = :encode
      self.unmarshal_class_method = :decode
      self.service_name = 'prefab.RateLimitService'

      rpc :LimitCheck, LimitRequest, LimitResponse
      rpc :UpsertLimitDefinition, LimitDefinition, BasicResponse
    end

    Stub = Service.rpc_stub_class
  end
  module ConfigService
    class Service

      include GRPC::GenericService

      self.marshal_class_method = :encode
      self.unmarshal_class_method = :decode
      self.service_name = 'prefab.ConfigService'

      rpc :GetConfig, ConfigServicePointer, stream(ConfigDeltas)
      rpc :Upsert, UpsertRequest, ConfigServicePointer
    end

    Stub = Service.rpc_stub_class
  end
end
