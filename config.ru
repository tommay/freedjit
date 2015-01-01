require "rubygems"
require "bundler/setup"

require "unxf"
require "clogger"
require "rack/contrib"

require_relative "server"

# Tell Sinatra we don't want json_csrf protection since it causes a
# 403 Forbidden when fetching /visit and the referer is not the host.
# Sinatra (or something) installs protection when
# RACK_ENV="production".

set :protection, :except => [:json_csrf]

# Remove "HTTP_X_FORWARDED_FOR" in the Rack environment and replace
# "REMOTE_ADDR" with the value of the original client address.

use UnXF

# Disable Sinatra logging.

disable :logging

# Use the Apache combined log format.  Sinatra logging will be disabled.

use Clogger,
  :logger => $stderr,
  :format => :Combined,
  :reentrant => true

#use Rack::Session::Cookie,
#  :key => settings.name,
#  :expire_after => 10*365*86400,
#  :secret => settings.secret

# Add JSON-P support by stripping out the callback param and padding
# the response with the appropriate callback format.

use Rack::JSONP

run Sinatra::Application
