module Prefab
  class ConfigValueWrapper
    def self.wrap(value)
      case value
      when Integer
        PrefabProto::ConfigValue.new(int: value)
      when Float
        PrefabProto::ConfigValue.new(double: value)
      when TrueClass, FalseClass
        PrefabProto::ConfigValue.new(bool: value)
      when Array
        PrefabProto::ConfigValue.new(string_list: PrefabProto::StringList.new(values: value.map(&:to_s)))
      else
        PrefabProto::ConfigValue.new(string: value.to_s)
      end
    end
  end
end
