# frozen_string_literal: true

require_relative "testlab_sdk_ruby/version"

require "testlab_sdk_ruby/testlab_client"

class Config
  def initialize(server_address, interval)
    @server_address = server_address
    @interval = interval
  end

  def connect
    client =
      Client.new({ server_address: @server_address, interval: @interval })
    client.fetch_features
    client.add_default_context
    client.timed_fetch(@interval)
    client
  end
end
