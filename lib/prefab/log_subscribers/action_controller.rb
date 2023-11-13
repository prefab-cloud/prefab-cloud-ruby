module Prefab
  module LogSubscribers
    class ActionController < ActiveSupport::LogSubscriber

      INTERNAL_PARAMS = %w[controller action format _method only_path].freeze

      LOG = Prefab::StaticLogger.new("rails.controller.request")

      # With great debt to https://github.com/reidmorrison/rails_semantic_logger/blob/master/lib/rails_semantic_logger/action_controller/log_subscriber.rb
      def process_action(event)
        payload = event.payload.dup
        payload.delete(:headers)
        payload.delete(:request)
        payload.delete(:response)
        params = payload[:params]

        if params.kind_of?(Hash) || params.kind_of?(::ActionController::Parameters)
          payload[:params] = params.to_unsafe_h unless params.is_a?(Hash)
          payload[:params] = params.except(*INTERNAL_PARAMS)

          if payload[:params].empty?
            payload.delete(:params)
          elsif params["file"]
            # When logging to JSON the entire tempfile is logged, so convert it to a string.
            payload[:params]["file"] = params["file"].inspect
          end
        end

        # Rounds off the runtimes. For example, :view_runtime, :mongo_runtime, etc.
        payload.keys.each do |key|
          payload[key] = payload[key].to_f.round(2) if key.to_s =~ /(.*)_runtime/
        end

        LOG.info "#{payload[:status]} #{payload[:controller]}##{payload[:action]}", **payload
      end
    end
  end
end
