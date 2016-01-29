# Store visits to mongodb.

require "mongo"
require "bson"

class VisitStoreMongo
  def initialize(mongo_client)
    @client = mongo_client
  end

  def save(key, visit)
    # Don't bother storing null or false values.

    hash = visit.to_hash.reject!{|k,v| !v}

    # Don't bother with id == "none" either.

    if hash["id"] == "none"
      hash.delete("id")
    end

    # Use the visit's time instead of the default current time in the
    # document _id so visits sort by their time.

    hash["_id"] = BSON::ObjectId.from_time(hash.delete("time"), unique: true)

    begin
      @client[key].insert_one(hash)
    rescue => ex
      puts "Failed to save visit: #{ex.inspect}"
    end
  end

  def each_not(key, id, ip, &block)
    @client[key].
      find(id ? {id: {"$ne" => id}} : {ip: {"$ne" => ip}}).
      sort("_id": -1).batch_size(30).each do |hash|
      hash["time"] = hash.delete("_id").generation_time.to_i
      yield(Visit.new(hash))
    end
  end
end
