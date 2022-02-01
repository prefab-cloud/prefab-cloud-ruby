require 'prefab-cloud-ruby'
require 'rack'

$client = Prefab::Client.new(
  api_key: "1|local_development_api_key",
)
puts $client.config_client.get("http-timeout")

handler = Rack::Handler::Thin
class RackApp
  def call(env)
    puts env
    [200, {"Content-Type" => "text/plain"}, $client.config_client.get("http-timeout").to_s]
  end
end
handler.run RackApp.new


def main
  $client.config_client.get("http-timeout")
end
main
