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
  feature = features.find { |f| f["name"] == name }
  raise TypeError, "Provided name does not match any feature." if feature.nil?

  # Return false if current date is outside of date range for feature
  start_date = DateTime.parse(feature["start_date"])
  end_date = DateTime.parse(feature["end_date"])

  return false unless is_active?(start_date, end_date)

  # Return false if feature is not running (toggled off) or if the hashed ID is outside of the target user_percentage range
  # For Type 3 (features), users can only be assigned to one feature (total percentage of users enrolled in features can not exceed 100%)

  case feature["type_id"]
  when 1
    feature["is_running"]
  when 2
    hashed_id = hash_message(user_id + name)
    feature["is_running"] && hashed_id < feature["user_percentage"]
  when 3
    hashed_id = hash_message(user_id)
    type_3_features =
      features.filter do |f|
        f["type_id"] == 3 &&
          is_active?(
            DateTime.parse(f["start_date"]),
            DateTime.parse(f["end_date"]),
          )
      end
    segment_start = 0
    segment_end = 0

    type_3_features.each do |exp|
      segment_end += exp["user_percentage"]
      if hashed_id >= segment_start && hashed_id <= segment_end &&
           exp["name"] == name
        return true
      else
        segment_start = segment_end
      end
    end
  end

  false
end

def get_variant(features, name, user_id)
  hashed_id = hash_message(user_id)
  puts "uuid, hashed #{user_id}, #{hashed_id}"

  feature = features.find { |f| f["name"] == name }
  raise TypeError, "Provided name does not match any feature." unless feature

  variants = feature["variant_arr"]
  type3features = features.select { |f| f["type_id"] == 3 }
  segment_start, segment_end = 0, 0

  type3features.each do |exp|
    segment_end += exp["user_percentage"]
    if hashed_id >= segment_start && hashed_id <= segment_end &&
         exp["name"] == name
      running_total = segment_start
      variants.each do |variant|
        running_total += variant["weight"].to_f * variant["weight"].to_f
        return variant if hashed_id <= running_total
      end
    else
      segment_start = segment_end
    end
  end

  return false
end
