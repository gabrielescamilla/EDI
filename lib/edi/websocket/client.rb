require 'faye/websocket'
require 'eventmachine'

module Websocket
  class Client
    attr_accessor :ws_url, :client, :id, :connected

    def initialize(url: nil)
      @id = 0
      @ws_url = url
    end

    def connect
      connection = EDI.get("https://slack.com/api/rtm.start?token=#{EDI.bot_token}").response
      if connection["channels"]
        connection["channels"].each do |c|
          EDI.add_channel Slack::Channel.new(name: c["name"], id: c["id"])
        end
      end
      @ws_url ||= connection["url"] # memoized pattern for testing convenience
      EM.run {

        self.client = Faye::WebSocket::Client.new(ws_url)

        # Respond to Messages
        client.on :message do |event|
          incoming_message = Slack::WebsocketIncomingMessage.new(event.data)
          if incoming_message.should_respond?
            EDI.logger.info "EDI received message #{incoming_message.text} in channel #{incoming_message.channel}"
            response_text = ""
            service = Proc.new { response_text = EDI.runner.new(message: incoming_message).execute }
            response = Proc.new { client.send Slack::WebsocketOutgoingMessage.new(text: response_text, channel: incoming_message.channel, id: id).to_json if response_text }
            EM.defer service, response
          end
        end

        # Kepp Websocket Connection Alive
        EM.add_periodic_timer(1) do
          client.ping
        end
      }
    end

    def send_message(message, channel_name: "general", channel_id: nil)
      unless channel_id
        channel_id = lookup_channel_by_name(channel_name).id
      end
      client.send Slack::WebsocketOutgoingMessage.new(text: message, channel: channel_id, id: id).to_json
    end

private

    def lookup_channel_by_name(name)
      Slack::Channel.find_by_name(name)
    end

    # There has to be a way to do this better
    def id
      @id += 1
    end
  end
end
