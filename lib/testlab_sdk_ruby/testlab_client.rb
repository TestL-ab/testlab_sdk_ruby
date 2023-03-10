require "testlab_sdk_ruby/testlab_feature_logic"
require "securerandom" # uuid = SecureRandom.uuid
require "httparty"
require "rufus-scheduler"

class Client
  attr_accessor :config, :context, :features

  def initialize(config)
    @config = config
    @context = nil
    @features = {}
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
    feature = @features.find { |f| f["name"] == name }
    return false unless feature

    if feature["type_id"] != 3
      return is_enabled(features, name, context[:user_id])
    else
      enabled = is_enabled(features, name, context[:user_id])
      # return false unless enabled
      variant = get_variant(features, name, context[:user_id])
      users = get_users
      existing_user =
        users.find do |user|
          user["id"] == context[:user_id] && user["variant_id"] == variant["id"]
        end
      if enabled && variant && !existing_user
        create_user(context[:user_id], variant["id"], context[:ip])
      end
      enabled && variant
    end
  end

  def get_features
    url = "#{config[:server_address]}/api/feature"
    response = HTTParty.get(url)
    self.features = response.parsed_response
  end

  def timed_fetch(interval)
    if interval > 0
      scheduler = Rufus::Scheduler.new
      scheduler.every "#{interval}.s" do
        fetch_features
      end
      Thread.new { scheduler.join }
    end
  end

  def fetch_features
    url = "#{config[:server_address]}/api/feature"
    last_modified = Time.now - config[:interval]

    response =
      HTTParty.get(
        url,
        options: {
          headers: {
            "If-Modified-Since" => last_modified.rfc2822,
          },
        },
      )
    puts response.parsed_response
    self.features = response.parsed_response if response.code == 200
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

# myClient = Client.new({ server_address: "http://localhost:3000", interval: 10 })
# myClient.add_default_context
# myClient.get_features
# puts myClient.context[:user_id]
# puts myClient.get_feature_value("new_experiment")
