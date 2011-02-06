#!/usr/bin/env ruby

require "rubygems"
require "sinatra"
require "haml"

# XXX how to set :secret for session cookies?  rack.session.options?
enable :sessions

set :haml, :escape_html => true

get "/" do
  haml :index
end

get "/v" do
  @last = session[:last]
  @ip = request.ip
  @title = params[:title]
  @url = params[:url]
  session[:last] = Time.now
  haml :v
end
