module Prefab
  class LoggerClient

    def initialize(base_client, base_logger)
      @base_client = base_client
      @base_logger = base_logger
    end

    def info msg
      pf_log :info, msg, caller_locations(1, 1)[0]
    end

    def debug msg
      pf_log :debug, msg, caller_locations(1, 1)[0]
    end

    def warn msg
      pf_log :warn, msg, caller_locations(1, 1)[0]
    end

    def pf_log level, msg, loc
      path = loc.absolute_path + ""
      path.slice! Dir.pwd

      path = "#{path.gsub("/", ":").gsub(".rb", "")}:#{loc.base_label}"
      path.slice! ":"

      base = "log_level"
      closest_log_level_match = @base_client.config_client.get(base) || :warn
      path.split(":").inject([base]) do |memo, n|
        memo << n
        val = @base_client.config_client.get memo.join(".")
        unless val.nil?
          closest_log_level_match = val
        end
        memo
      end
      if val(closest_log_level_match) <= val(level)
        @base_logger.unknown "#{level.to_s.upcase.ljust(5)} #{path} #{msg}"
      end
    end

    def val level
      case level.to_sym
      when :debug then
        1
      when :info then
        2
      when :warn then
        3
      when :error then
        4
      end
    end
  end
end

