# Read configuration from mongodb.

require "mongo"

class ConfigFromMongo
  def initialize(mongo_client)
    @client = mongo_client
  end

  # Returns
  # {
  #   "<key>" => {
  #     "NAME" => "who",
  #     ...,
  #   },
  #   "<key>" => {
  #     "NAME" => "who",
  #     ...,
  #   },
  # }
  def load_config
    @client["config"].find.map do |config|
      [config["key"], config]
    end.to_h
  end
end
