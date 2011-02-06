#!/usr/bin/env ruby

require "rubygems"
require "sinatra"
require "haml"

load "visit.rb"
load "bounded_list.rb"

# XXX how to set :secret for session cookies?  rack.session.options?
enable :sessions

set :haml, :escape_html => true

visits = BoundedList.new(1000)
log = File.open("log/visits.log", "a")

get "/" do
  haml :index
end

get "/v" do
  session[:id] ||= ("%08x" % rand(1 << 32))

  title = params[:title]
  title = nil unless title && title.size > 0

  url = params[:url]
  url = nil unless url && url.size > 0

  visit = Visit.new(session[:id], request.ip, url, title)
  visits.add(visit)

  log.write("#{visit.time}|#{visit.id}|#{visit.ip}|#{visit.url}|#{visit.title}\n")
  log.flush

  "ok"
end

get "/list" do
  @list = visits.get(6)
  haml :list
end

get "/sand" do
  haml :sand
end
