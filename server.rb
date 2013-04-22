require 'em-hiredis'
require 'goliath'

class Server < Goliath::API
  use Rack::Static, :urls => ["/index.html"], :root => Goliath::Application.app_path("public")
  use Goliath::Rack::Params

  attr_accessor :redis

  def response(env)
    path = env[Goliath::Request::REQUEST_PATH]
    env.logger.info "Path is #{path}"
    return [404, {}, 'Not found'] unless path == '/events'

    env['redis'] = EM::Hiredis.connect
    env['redis'].pubsub.subscribe('ch1') do |msg|
      env.logger.info "Got message: #{msg}"
      env.stream_send("data:#{msg}\n\n")
    end
    env['redis'].pubsub.subscribe('ch2') do |msg|
      env.logger.info "Got message: #{msg}"
      env.stream_send(["event:special", "data:#{msg}\n\n"].join("\n"))
    end

    streaming_response(200, {'Content-Type' => 'text/event-stream'})
  end

  def on_close(env)
    env.logger.info "Connection closed; unsubscribing"
    return unless env['redis']

    env['redis'].pubsub.unsubscribe('ch1')
    env['redis'].pubsub.unsubscribe('ch2')
    env['redis'].pubsub.close
    env['redis'] = nil
  end
end
