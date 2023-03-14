require "testlab_sdk_ruby/testlab_feature_logic"
require "securerandom" # uuid = SecureRandom.uuid
require "httparty"

class Client
  attr_accessor :config, :context, :features

  def initialize(config)
    @config = config
    @context = nil
    @features = {}
    @process_thread = nil
  end

  def add_default_context
    self.context = { user_id: SecureRandom.uuid, ip: get_ip }
  end

  def update_context(new_context)
    self.context = context.merge(new_context)
  end

  def get_ip
    response = HTTParty.get("https://ipapi.co/json/")
    response.parsed_response["ip"]
  end

  def get_feature_value(name)
    feature =
      features["experiments"]
        .concat(features["toggles"], features["rollouts"])
        .find { |f| f["name"] == name }

    return false unless feature

    if feature["type_id"] != 3
      return is_enabled(features, name, context[:user_id])
    else
      enabled = is_enabled(features, name, context[:user_id])
      variant = get_variant(features, name, context[:user_id])
      users = get_users
      existing_user =
        users.find do |user|
          user["id"] == context[:user_id] && user["variant_id"] == variant["id"]
        end
      if enabled && variant && !existing_user
        create_user(context[:user_id], variant[:id], context[:ip])
      end
      enabled && variant
    end
  end

  def timed_fetch(interval)
    disconnect

    @process_thread =
      Thread.new do
        loop do
          fetch_features
          sleep interval
        end
      end
  end

  def disconnect
    # Stop the previous process if it exists
    @process_thread&.kill
  end

  def fetch_features
    url = "#{config[:server_address]}/api/feature/current"

    if not features.empty?
      last_modified = Time.now - config[:interval]

      response =
        HTTParty.get(
          url,
          headers: {
            "If-Modified-Since" => last_modified.httpdate,
          },
        )
      self.features = response.parsed_response if response.code == 200
    else
      response = HTTParty.get(url)
      self.features = response.parsed_response
    end
  end

  def get_users
    url = "#{config[:server_address]}/api/users"
    response = HTTParty.get(url)
    response.parsed_response
  end

  def create_user(id, variant_id, ip_address)
    url = "#{config[:server_address]}/api/users"

    response =
      HTTParty.post(
        url,
        {
          body: {
            id: id,
            variant_id: variant_id,
            ip_address: ip_address,
          }.to_json,
          headers: {
            "Content-Type" => "application/json",
          },
        },
      )
    if response.code == 200
      return response.parsed_response
    else
      puts "Error creating user: #{response.body}"
      return response.parsed_response
    end
  end

  def create_event(variant_id, user_id)
    url = "#{config[:server_address]}/api/events"

    response =
      HTTParty.post(
        url,
        {
          body: { variant_id: variant_id, user_id: user_id }.to_json,
          headers: {
            "Content-Type" => "application/json",
          },
        },
      )
    if response.code == 200
      return response.parsed_response
    else
      puts "Error creating user: #{response.body}"
      return response.parsed_response
    end
  end
end
