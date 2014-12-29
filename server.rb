#!/usr/bin/env ruby

require "uri"
require "set"

require "sinatra"
require "haml"
require "erb"
require "geoip"

require_relative "visit"
require_relative "visit_store_mongo"

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

# F_EXCLUDES is a colon-separated list of ip addresses to not track as
# visitors.

set :excludes, ENV["F_EXCLUDES"].split(":")

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

  def page_ok?(url)
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
  key = params[:key]

  # document.URL (url for the page containing the javascript)
  page = params[:page] || ""
  page.sub!(%r{://www\.}, "://")

  title = params[:title]

  # href scraped from the page's title html that links to the page.
  url = params[:url] || ""
  url.sub!(%r{://www\.}, "://")

  # document.referrer, i.e., page the user came from.
  referrer = params[:ref]

  @ok = key_ok?(key) && page_ok?(page) && page_ok?(url)

  session = {} # XXX

  if @ok && !session[:ignore] && !settings.excludes.include?(request.ip)
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
       "url" => url,
       "title" => string_or_nil(title),
       "city" => (geo[:city_name].encode("UTF-8") rescue nil),
       "region" => geo[:region_name],
       "country" => geo[:country_name],
       "country_code" => geo[:country_code2],
       "user_agent" => request.user_agent,
       "page" => page,
       "referrer" => string_or_nil(referrer))

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

get "/clear" do
  session = {}
  if params[:password] == settings.password
    session.delete(:id)
  end
  "cleared"
end
