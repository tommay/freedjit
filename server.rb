#!/usr/bin/env ruby

require "rubygems"
require "sinatra"
require "haml"

load "visit.rb"
load "bounded_list.rb"

secret = ENV["F_SECRET"]

use Rack::Session::Cookie,
  :key => 'freedjit',
  :expire_after => 10*365*86400,
  :secret => secret

#set :haml, :escape_html => true

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

get "/visit" do
  if session[:id].nil? || session[:id].size != 16
    session[:id] = "%.16x" % rand(1 << 64)
    new_visitor = true
  end

  title = params[:title]
  title = nil unless title && title.size > 0

  url = params[:url]
  url = nil unless url && url.size > 0

  visit = Visit.new(session[:id], request.ip, new_visitor, url, title)
  visits.add(visit)

  log.write("#{visit.time}|#{visit.id}|#{visit.new? ? "t" : "f"}|#{visit.ip}|#{visit.url}|#{visit.title}|#{request.user_agent}\n")
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
