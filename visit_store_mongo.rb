# Store visits to mongodb.

require "mongo"
require "bson"

class VisitStoreMongo
  def initialize(mongo_uri)
    conn = Mongo::Connection.from_uri(mongo_uri)
    @db = conn.db(mongo_uri.sub(%r{.*/}, ""))
  end

  def save(key, visit)
    hash = visit.to_hash
    hash["_id"] = BSON::ObjectId.from_time(hash.delete("time"))
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
