def hash_message(message)
  hash = 0
  message.each_char do |c|
    hash = (hash << 5) - hash + c.ord
    hash &= 0xFFFFFFFF # Convert to 32-bit integer
  end
  (hash.to_f / 2**32).abs # Scale to [0, 1]
end

def is_active?(start_date, end_date)
  current_date = DateTime.now
  current_date >= start_date && current_date <= end_date
end

def is_enabled(features, name, user_id)
  # Find target feature based on name
  feature =
    features["experiments"]
      .concat(features["toggles"], features["rollouts"])
      .find { |f| f["name"] == name }
  # feature = features.find { |f| f["name"] == name }
  return false unless feature

  # Return false if current date is outside of date range for feature
  start_date = DateTime.parse(feature["start_date"])
  end_date = DateTime.parse(feature["end_date"])

  return false unless is_active?(start_date, end_date) && feature["is_running"]

  # Return false if feature is not running (toggled off) or if the hashed ID is outside of the target user_percentage range
  # For Type 3 (features), users can only be assigned to one feature (total percentage of users enrolled in features can not exceed 100%)

  case feature["type_id"]
  when 2
    hashed_id = hash_message(user_id + name)
    feature["is_running"] && hashed_id < feature["user_percentage"]
  when 3
    hashed_id = hash_message(user_id)
    blocks = features["userblocks"]
    block_id = (hashed_id * blocks.length).ceil

    !blocks
      .filter { |b| b["id"] == block_id && b["feature_id"] == feature["id"] }
      .empty?
  else
    false
  end
end

def get_variant(features, name, user_id)
  hashed_id = hash_message(user_id)
  puts "uuid, hashed #{user_id}, #{hashed_id}"

  feature =
    features["experiments"]
      .concat(features["toggles"], features["rollouts"])
      .find { |f| f["name"] == name }
  return false unless feature

  variants = feature["variant_arr"]
  blocks = features["userblocks"]
  block_id = (hashed_id * blocks.length).ceil

  target_block =
    blocks
      .filter { |b| b["id"] == block_id && b["feature_id"] == feature["id"] }
      .first

  return false unless target_block

  segment_end = target_block["id"].to_f / blocks.length
  segment_start = segment_end - 1.0 / blocks.length

  running_total = segment_start
  variants.each do |variant|
    running_total += variant["weight"].to_f * (1.0 / blocks.length)
    if hashed_id <= running_total
      return { id: variant["id"], value: variant["value"] }
    end
  end

  false
end
