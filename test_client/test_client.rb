require 'prefab-cloud-ruby'
require 'rack'
require 'base64'
require 'json'

handler = Rack::Handler::Thin

class RackApp
  def call(env)
    props = CGI::parse(env["QUERY_STRING"])
    props = JSON.parse(Base64.decode64(props["props"][0]))

    key = props["key"]
    namespace = props["namespace"]
    environment = props["environment"]
    user_key = props["user_key"]

    client = Prefab::Client.new(
      api_key: "1-#{environment}-local_development_api_key", #sets environment
      namespace: namespace,
    )

    puts "Key #{key}"
    puts "User #{user_key}"
    puts "Environment #{environment}"
    puts "Namespace #{namespace}"
    puts "Props #{props}"
    # puts client.config_client.to_s

    [200, { "Content-Type" => "text/plain" }, client.config_client.get(key).to_s]
  end
end

handler.run RackApp.new
