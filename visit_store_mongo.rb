# Store visits to mongodb.

require "mongo"
require "bson"

class VisitStoreMongo
  def initialize(mongo_uri)
    conn = Mongo::Connection.from_uri(mongo_uri, pool_size: 2)
    @db = conn.db(mongo_uri.sub(%r{.*/}, ""))
  end

  def save(key, visit)
    # Don't bother storing null or false values.

    hash = visit.to_hash.reject!{|k,v| !v}

    # Don't bother with id == "none" either.

    if hash["id"] == "none"
      hash.delete("id")
    end

    # Use the visit's time instead of the default current time in the
    # document _id.

    hash["_id"] = BSON::ObjectId.new(nil, hash.delete("time"))

    @db.collection(key).insert(hash)
  end

  def each_not(key, id, ip, &block)
    @db.collection(key).
      find(id ? {"id" => {"$ne" => id}} : {"ip" => {"$ne" => ip}}).
      sort("_id", :desc).batch_size(30).each do |hash|
      hash["time"] = hash.delete("_id").generation_time.to_i
      yield(Visit.new(hash))
    end
  end
end
