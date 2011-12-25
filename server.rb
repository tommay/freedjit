#!/usr/bin/env ruby

require "rubygems"
require "sinatra"
require "rack/contrib"
require "unxf"
require "clogger"
require "haml"
require "erb"
require "json"
require "geoip"
require "uri"
require "set"

$LOAD_PATH << "."

require "visit"
require "visit_store_mongo"

set :name, ENV["F_NAME"]
set :key, ENV["F_KEY"]
set :host, ENV["F_HOST"]
set :dir, ENV["F_DIR"] || "log"
set :password, ENV["F_PASSWORD"]
secret = ENV["F_SECRET"]

mongo_uri = ENV['MONGOLAB_URI'] || "mongodb://localhost/freedjit-test"

set :flags, (Dir["public/images/flags/*.gif"].map do |name|
  File.basename(name, ".gif").downcase
end.to_set)

disable :logging

# Set REMOTE_ADDR from X-Forwarded-For.
use UnXF

use Clogger,
  :logger => $stderr,
  :format => Clogger::Format::Combined,
  :reentrant => true

#use Rack::Session::Cookie,
#  :key => 'freedjit',
#  :expire_after => 10*365*86400,
#  :secret => secret

use Rack::JSONP

#set :haml, :escape_html => true

geoip = GeoIP.new("maxmind/GeoLiteCity.dat")

visit_store = VisitStoreMongo.new(mongo_uri)

helpers do
  def string_or_nil(val)
    (val && val.size > 0) ? val : nil
  end

  def key_ok?(key)
    key == settings.key
  end

  def url_ok?(url)
    uri = URI.parse(url) rescue nil
    uri.respond_to?(:host) && uri.host == settings.host &&
      uri.respond_to?(:path) && uri.path !~ %r{^/b/}
  end

  def flag_url(country_code)
    country_code = country_code.downcase
    if settings.flags.include?(country_code)
      port = ":#{request.port}" unless request.port == 80
      "http://#{request.host}#{port}/images/flags/#{country_code}.gif"
    end
  end
end

before do
  response["P3P"] = "CP=\"IDC DSP COR ADM DEVi TAIi PSA PSD IVAi IVDi CONi HIS OUR IND CNT\""
end

get "/" do
  haml :index
end

get "/#{settings.name}.js" do
  @key = params[:key]
  halt 404 unless @key && @key =~ /[a-zA-Z0-9\-]+/
  @name = settings.name
  @server = request.host
  @server << ":#{request.port}" if request.port != 80
  content_type :js
  last_modified File.stat("views/freedjit.js.erb").mtime
  erb(:"freedjit.js")
end

get "/visit" do
  # We test url just to filter out /b/.  Should do this better.

  url = params[:url]
  url.sub!(%r{://www\.}, "://") if url

  h = params[:h]
  h = params[:url] if !h || h == ""
  h.sub!(%r{://www\.}, "://") if h

  title = params[:t]
  title = params[:title] if !title || title == ""

  referrer = params[:ref]

  key = params[:key]

  @ok = key_ok?(key) && url_ok?(url) && url_ok?(h)

  session = {} # XXX

  if @ok && !session[:ignore]
    if session[:id].nil? || session[:id].size != 16
      session[:id] = "none" # XXX "%.16x" % rand(1 << 64)
      new_visitor = true
    end

    geo = geoip.city(request.ip)
    geo = geo ? geo.to_hash : {}

    visit = Visit.new(
       "id" => session[:id],
       "ip" => request.ip,
       "new_visitor" => new_visitor,
       "url" => h,
       "title" => string_or_nil(title),
       "city" => (geo[:city_name].encode("UTF-8") rescue nil),
       "region" => geo[:region_name],
       "country" => geo[:country_name],
       "country_code" => geo[:country_code2],
       "user_agent" => request.user_agent,
       "referrer" => referrer)

    visit_store.save(key, visit)
  end

  content_type :json, :charset => "utf-8"
  erb(:"visit.js")
end

get "/list" do
  session = {}
  @list = []
  key = params[:key]
  if key_ok?(key)
    id = session[:id]
    ip = request.ip
    visit_store.each_not(key, id, ip) do |v|
      @list << v unless @list.any? do |e|
        e.same_visitor?(v) && e.display_title == v.display_title
      end
      break if @list.size == 6
    end
  end

  @html = haml(:list)

  content_type :json, :charset => "utf-8"
  erb(:"list.js")
end

get "/ignore" do
  session = {}
  if params[:password] == settings.password
    session[:ignore] = true
  else
    session.delete(:ignore)
  end
  "ok"
end

get "/sand" do
  haml :sand
end

get "/clear" do
  session = {}
  if params[:password] == settings.password
    session.delete(:id)
  end
  "cleared"
end
