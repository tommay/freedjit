#!/usr/bin/env ruby

require "rubygems"
require "sinatra"
require "haml"
require "geoip"
require "uri"

load "visit.rb"
load "bounded_list.rb"

set :key, ENV["F_KEY"]
set :host, ENV["F_HOST"]
set :password, ENV["F_PASSWORD"]
secret = ENV["F_SECRET"]

use Rack::Session::Cookie,
  :key => 'freedjit',
  :expire_after => 10*365*86400,
  :secret => secret

#set :haml, :escape_html => true

visits = BoundedList.new(1000)
geoip = GeoIP.new("maxmind/GeoLiteCity.dat")
log = File.open("log/visits.log", "a")

helpers do
  def jsonp(callback, json)
    content_type "application/json"
    "#{callback}('#{json.gsub(/\n/, "").gsub(/'/, "\\\\'")}')"
  end

  def string_or_nil(val)
    (val && val.size > 0) ? val : nil
  end

  def key_ok?
    params[:key] == settings.key
  end

  def url_ok?(url)
    uri = URI.parse(url) rescue nil
    uri.respond_to?(:host) && uri.host == settings.host &&
      uri.respond_to?(:path) && uri.path !~ %r{^/b/}
  end
end

get "/" do
  haml :index
end

get "/visit" do
  url = params[:url]
  url.sub!(%r{://www\.}, "://") if url
  if key_ok? && url_ok?(url) && !session[:ignore]
    if session[:id].nil? || session[:id].size != 16
      session[:id] = "%.16x" % rand(1 << 64)
      new_visitor = true
    end

    geo = geoip.city(request.ip)
    geo = geo ? geo.to_hash : {}

    visit = Visit.new(
       :id => session[:id],
       :ip => request.ip,
       :new_visitor => new_visitor,
       :url => url,
       :title => string_or_nil(params[:title]),
       :city => (geo[:city_name].encode("UTF-8") rescue nil),
       :region => geo[:region_name],
       :country => geo[:country_name],
       :country_code => geo[:country_code2])
    visits.add(visit)

    log.write("#{visit.time}|#{visit.id}|#{visit.new? ? "t" : "f"}|#{visit.ip}|#{visit.url}|#{visit.title}|#{visit.city}|#{visit.region}|#{visit.country}|#{visit.country_code}|#{request.user_agent}\n")
    log.flush
  end

  jsonp(params[:callback], "ok")
end

get "/list" do
  if key_ok?
    id = session[:id]
    ip = request.ip
    @list = visits.all.select{|v| id ? v.id != id : v.ip != ip}[0..5]
  else
    @list = []
  end
  jsonp(params[:callback], haml(:list))
end

get "/ignore" do
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
  if params[:password] == settings.password
    session.delete(:id)
  end
  "cleared"
end
