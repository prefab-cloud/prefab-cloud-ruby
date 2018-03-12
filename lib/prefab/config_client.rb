module Prefab
  class ConfigClient
    RECONNECT_WAIT = 5
    CHECKPOINT_LOCK = 20
    DEFAULT_CHECKPOINT_FREQ_SEC = 10
    DEFAULT_MAX_CHECKPOINT_AGE_SEC = 60

    def initialize(base_client, timeout)
      @base_client = base_client
      @timeout = timeout
      @initialization_lock = Concurrent::ReadWriteLock.new

      @checkpoint_max_age_secs = (ENV["PREFAB_CHECKPOINT_MAX_AGE_SEC"] || DEFAULT_MAX_CHECKPOINT_AGE_SEC)
      @checkpoint_max_age = @checkpoint_max_age_secs * 1000 * 10000
      @checkpoint_freq_secs = (ENV["PREFAB_DEFAULT_CHECKPOINT_FREQ_SEC"] || DEFAULT_CHECKPOINT_FREQ_SEC)

      @config_loader = Prefab::ConfigLoader.new(@base_client)
      @config_resolver = Prefab::ConfigResolver.new(@base_client, @config_loader)

      @initialization_lock.acquire_write_lock

      start_checkpointing_thread
    end

    def get(prop)
      @initialization_lock.with_read_lock do
        @config_resolver.get(prop)
      end
    end

    def upsert(key, config_value, namespace = nil, previous_key = nil)
      raise "key must not contain ':' set namespaces separately" if key.include? ":"
      raise "namespace must not contain ':'" if namespace&.include?(":")
      config_delta = Prefab::ConfigClient.value_to_delta(key, config_value, namespace)
      upsert_req = Prefab::UpsertRequest.new(config_delta: config_delta)
      upsert_req.previous_key = previous_key if previous_key&.present?

      @base_client.request Prefab::ConfigService, :upsert, req_options: { timeout: @timeout }, params: upsert_req

      @config_loader.set(config_delta)
      @config_loader.rm(previous_key) if previous_key&.present?
      @config_resolver.update
    end

    def reset
      @base_client.reset!
      @_stub = nil
    end

    def to_s
      @config_resolver.to_s
    end

    def self.value_to_delta(key, config_value, namespace = nil)
      Prefab::ConfigDelta.new(key: [namespace, key].compact.join(":"),
                              value: config_value)
    end

    private

    def stub
      @_stub = Prefab::ConfigService::Stub.new(nil,
                                               nil,
                                               channel_override: @base_client.channel,
                                               interceptors: [@base_client.interceptor])
    end

    # Bootstrap out of the cache
    # returns the high-watermark of what was in the cache
    def load_checkpoint
      checkpoint = @base_client.shared_cache.read(checkpoint_cache_key)

      if checkpoint
        deltas = Prefab::ConfigDeltas.decode(checkpoint)
        deltas.deltas.each do |delta|
          @config_loader.set(delta)
        end
        @base_client.log_internal Logger::INFO, "Found checkpoint with highwater id #{@config_loader.highwater_mark}"
        @config_resolver.update
        finish_init!
      else
        @base_client.log_internal Logger::INFO, "No checkpoint"
      end
    end

    # Save off the config to a local cache as a backup
    #
    def save_checkpoint
      begin
        deltas = @config_resolver.export_api_deltas
        @base_client.log_internal Logger::DEBUG, "Save Checkpoint #{@config_loader.highwater_mark} Thread #{Thread.current.object_id}"
        @base_client.shared_cache.write(checkpoint_cache_key, Prefab::ConfigDeltas.encode(deltas))
        @base_client.shared_cache.write(checkpoint_highwater_cache_key, @config_loader.highwater_mark)
      rescue StandardError => exn
        @base_client.log_internal Logger::INFO, "Issue Saving Checkpoint #{exn.message}"
      end
    end

    # A thread that saves current state to the cache, "checkpointing" it
    def start_checkpointing_thread
      Thread.new do
        loop do
          begin
            checkpoint_if_needed

            started_at = Time.now
            delta = @checkpoint_freq_secs - (Time.now - started_at)
            if delta > 0
              sleep(delta)
            end
          rescue StandardError => exn
            @base_client.log_internal Logger::INFO, "Issue Checkpointing #{exn.message}"
          end
        end
      end
    end

    # check what our shared highwater mark is
    # if it is higher than our own highwater mark, we must have missed something, so load the checkpoint
    # if it is lower than our own highwater mark, save a checkpoint
    # if everything is up to date, but the shared highwater mark is old, coordinate amongst other processes to have
    #    one process "double check" by restarting the API thread
    def checkpoint_if_needed
      shared_highwater_mark = get_shared_highwater_mark
      @base_client.log_internal Logger::DEBUG, "Checkpoint_if_needed apx ahead/behind #{(@config_loader.highwater_mark - shared_highwater_mark) / (1000 * 10000)}"

      if shared_highwater_mark > @config_loader.highwater_mark
        @base_client.log_internal Logger::DEBUG, "We were behind, loading checkpoint"
        load_checkpoint
      elsif shared_highwater_mark < @config_loader.highwater_mark
        @base_client.log_internal Logger::DEBUG, "Saving off checkpoint"
        save_checkpoint
      elsif shared_highwater_is_old?
        if get_shared_lock?
          @base_client.log_internal Logger::DEBUG, "Shared highwater mark > PREFAB_CHECKPOINT_MAX_AGE #{@checkpoint_max_age_secs}. We have been chosen to run suspenders"
          reset_api_connection
        else
          @base_client.log_internal Logger::DEBUG, "Shared highwater mark > PREFAB_CHECKPOINT_MAX_AGE #{@checkpoint_max_age_secs}. Other process is running suspenders"
        end
      end
    end

    def current_time_as_id
      Time.now.to_f * 1000 * 10000
    end

    def shared_highwater_is_old?
      age = current_time_as_id - get_shared_highwater_mark
      @base_client.log_internal Logger::DEBUG, "shared_highwater_is_old? apx #{age / (1000 * 10000)}" if age > @checkpoint_max_age
      age > @checkpoint_max_age_secs
    end

    def get_shared_highwater_mark
      (@base_client.shared_cache.read(checkpoint_highwater_cache_key) || 0).to_i
    end

    def get_shared_lock?
      in_progess = @base_client.shared_cache.read(checkpoint_update_in_progress_cache_key)
      if in_progess.nil?
        @base_client.shared_cache.write(checkpoint_update_in_progress_cache_key, "true", { expires_in: CHECKPOINT_LOCK })
        true
      else
        false
      end
    end

    def reset_api_connection
      @api_connection_thread&.exit
      start_api_connection_thread(@config_loader.highwater_mark)
    end

    def finish_init!
      if @initialization_lock.write_locked?
        @initialization_lock.release_write_lock
        @base_client.log.set_config_client(self)
      end
    end

    # Setup a streaming connection to the API
    # Save new config values into the loader
    def start_api_connection_thread(start_at_id)
      config_req = Prefab::ConfigServicePointer.new(account_id: @base_client.account_id,
                                                    start_at_id: start_at_id)
      @base_client.log_internal Logger::DEBUG, "start api connection thread #{start_at_id}"
      @api_connection_thread = Thread.new do
        while true do
          begin
            resp = stub.get_config(config_req)
            resp.each do |r|
              r.deltas.each do |delta|
                @config_loader.set(delta)
              end
              @config_resolver.update
              finish_init!
            end
          rescue => e
            @base_client.log_internal Logger::INFO, ("config client encountered #{e.message} pausing #{RECONNECT_WAIT}")
            reset
            sleep(RECONNECT_WAIT)
          end
        end
      end
    end

    def checkpoint_cache_key
      "prefab:config:checkpoint"
    end

    def checkpoint_update_in_progress_cache_key
      "prefab:config:checkpoint:updating"
    end

    def checkpoint_highwater_cache_key
      "prefab:config:checkpoint:highwater"
    end
  end
end

