class FakeSlack
  attr_accessor :socket, :messages

  def initialize
    @messages = []
  end

  def call(env)
    self.socket = Faye::WebSocket.new(env, ["echo"])
    socket.onmessage = ->(event) { socket.send(event.data) }
    socket.rack_response
  end

  def log(*args)
  end

  def listen(port, backend, tls = false)
    case backend
    when :thin then listen_thin(port, tls)
    end
  end

  def stop
    @server.stop
  end

  def has_message?(message)
    puts "Checking Slack for message #{message}"
    puts "Messages: #{messages}"
    messages.include? message
  end

private
  def listen_thin(port, tls)
    Rack::Handler.get('thin').run(self, :Port => port) do |s|
      @server = s
    end
  end
end
