class Prefab::MigrationFallback
  LOG = Prefab::InternalLogger.new(self)

  def initialize(closure)
    @closure = closure
  end

  def get(key, context, default)
    LOG.debug "Migration fallback for key: #{key}"
    @closure.call(key, context, default)
  end
end
