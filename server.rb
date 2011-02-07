#!/usr/bin/env ruby

require "rubygems"
require "sinatra"
require "haml"

load "visit.rb"
load "bounded_list.rb"

use Rack::Session::Cookie,
  :key => 'freedjit',
  :expire_after => 10*365*86400,
  :secret => 'adk4r2'

set :haml, :escape_html => true

visits = BoundedList.new(1000)
log = File.open("log/visits.log", "a")

helpers do
  def jsonp(callback, json)
    "#{callback}('#{json.gsub(/\n/, "").gsub(/'/, "\\\\'")}')"
  end
end

get "/" do
  haml :index
end

get "/v" do
  id = session[:id]
  if id.nil?
    id = "%08x" % rand(1 << 32)
    session[:id] = id
    new_visitor = true
  end

  title = params[:title]
  title = nil unless title && title.size > 0

  url = params[:url]
  url = nil unless url && url.size > 0

  visit = Visit.new(session[:id], request.ip, new_visitor, url, title)
  visits.add(visit)

  log.write("#{visit.time}|#{visit.id}|#{visit.new? ? "t" : "f"}|#{visit.ip}|#{visit.url}|#{visit.title}\n")
  log.flush

  "ok"
end

get "/list" do
  callback = params[:callback]
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
