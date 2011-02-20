#!/usr/bin/env ruby

require "rubygems"
require "sinatra"
require "haml"
require "geoip"

load "visit.rb"
load "bounded_list.rb"

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
    "#{callback}('#{json.gsub(/\n/, "").gsub(/'/, "\\\\'")}')"
  end

  def string(val)
    (val && val.size > 0) ? val : nil
  end
end

get "/" do
  haml :index
end

get "/visit" do
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
     :url => string(params[:url]),
     :title => string(params[:title]),
     :city => (geo[:city_name].encode("UTF-8") rescue nil),
     :region => geo[:region_name],
     :country => geo[:country_name],
     :country_code => geo[:country_code2])
  visits.add(visit)

  log.write("#{visit.time}|#{visit.id}|#{visit.new? ? "t" : "f"}|#{visit.ip}|#{visit.url}|#{visit.title}|#{visit.city}|#{visit.region}|#{visit.country}|#{visit.country_code}|#{request.user_agent}\n")
  log.flush

  jsonp(params[:callback], "ok")
end

get "/list" do
  @list = visits.get(6)
  content_type 'application/json'
  jsonp(params[:callback], haml(:list))
end

get "/sand" do
  haml :sand
end

get "/clear" do
  session.delete(:id)
  "cleared"
end
