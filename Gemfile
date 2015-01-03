source "https://rubygems.org"

ruby "2.1.5"

gem "sinatra"
gem "puma"
gem "rack-contrib", :require => "rack/contrib"
gem "unxf"
gem "clogger"
gem "haml"
gem "mongo"
gem "bson"

# Install bson_ext for performance-critical apps
# (http://docs.mongodb.org/ecosystem/drivers/ruby/).  Not like this is
# performance-critical, but why not.

gem "bson_ext"
gem "maxminddb"

group :development do
  gem "heroku"
  gem "byebug"
end
