#!/usr/bin/env ruby

require "uri"

require "sinatra"
require "haml"
require "erb"
require "maxminddb"

require_relative "visit"
require_relative "visit_store_mongo"
require_relative "config_from_env"

# Freedjit is a widget that can be added to a blogspot page template.
# It logs visits to the blog, and displays a list of the N most recent
# visitors' cities and/or countries, with little country flag images.
# The list updates automatically once a minute.
#
# Freedjit was inspired by feedjit, but I wanted a free version.
# Country flags are provided by famfamfam.com.  IP->Geo mapping is
# provided by Maxmind's free GeoLite2-City database.  I've hosted
# freedjit on both EC2 and Heroku.
#
# When deploying to a single host, on EC2 for example, the visitor log
# can be stored in a flat file, but for a multi-host deployment or
# Heroku the visitor log needs to be kept in (semi-)durable off-host
# storage.  I use mongodb for that, because a) it's reasonably simple
# when I'm not forgetting how to use it, b) I could never attach to a
# Postgres database on Heroku.  mongodb is fine for a little app like
# this without much demand and little or no requirement for durability
# (i.e., if the data isn't backed up it's not a big deal, losing your
# visitor log isn't going to bring the world to a cataclysmic end).
#
# freedjit is built on three web requests handled by ruby+sinatra, and
# some javascript running on the browser.  Note that all JSONP
# responses return an object that includes an "apply" function which is
# run by the requester, so the response gets to specify how it should be
# "applied".
#
# /freedjit.js?key=<key>
#   This simple request is part of the widget code added to the template.
#   Key is the app key for a particular user.  If it isn't recognized
#   the request 404s.
#   The response is from views/freedjit.js; it scrounges up a few more
#   parameters from the containing page and makes a JSONP request to /visit.
# /visit
#   A JSONP get request with (see views/freedjit.js.erb for details about
#   where these values come from):
#     key: the key that was passed in the /freedjit.js request
#     page: document.URL of the containing page
#     title: title of the containing page
#     url: url of the containing page, or ""
#     ref: the containing page's referrer, or ""
#   Checks the request for proper authorization, bundles the
#   parameters into a Visit object, and saves the Visit to the store.
#   Returns javascript from views/visit.js.erb.  Its apply function
#   sets up a function "list" to be run every minute which gets /list
#   and runs the response's apply method.
# /list
#   key: XXX
#   Checks the key.  Returns a list of the last 6 visitors to the site
#   with ip different from the requester's ip.  I.e., you don't show up
#   as a visitor.
#   The html for the list is rendered by views/list.haml, and used by
#   the response's apply method as a replacement for the
#   #<name>-list element's html.
#
# Classes, ids, and CSS:
# list.haml uses the following classes, which can be specified in
# your blog's CSS to style things the way you want:
#   ul.visits
#     The ul containing an li element for each visit.  This styles
#     the text "A visitor" and "viewed", and the title of the page
#     they viewed (unless it's a link, then it's a.visit-link).
#   span.visit-where
#     The city/country the visitor was from.
#   img.visit-flag
#     The visitor's country flag image.
#   a.visit-link
#     Link to the page the visitor viewed.
#   div.visit-when
#     Time the visitor viewed the page.
# Additionally, freedjit expects that the widget will be in a template
# element with id "list".  It updates this element's html.
#
# Add this html as a widget.  The id='<name>-list' for the ul element
# is required (name is specified by the F_NAME environment variable):
#   <div id='<name>-list'>
#     <script src='http://ajax.googleapis.com/ajax/libs/jquery/1.5.0/jquery.min.js' type='text/javascript'></script>
#     <script src='http://localhost:4093/who.js?key=s69m9pslkv' type='text/javascript' async='async'></script>
#   </div>

# Get the configuraion settings from environment variables.

set :config, ConfigFromEnv.get_config

# Create a regular expression for each key that matches its host, with
# variations at the beginning (www., etc.) and end (.com, .ca, .co.uk,
# etc.).

settings.config.values.each do |c|
  c["host_re"] = %r{^(?:\w+\.)?#{Regexp.quote(c["host"])}(\.\w+){1,2}$}
end

# This is for use with /ignore and /clear requests, which give the
# browser a session cookie causing it to be ignored in subsequent
# requests.  Intended for the owner of the site to be able to use the
# site without giving their location away.

set :password, ENV["F_PASSWORD"]

# This is the secret to encode/decode session cookies.

set :secret, ENV["F_SECRET"]

mongo_uri = ENV["MONGOLAB_URI"]

# settings.country_flags is a Hash from country_iso_code => url path
# to use to get the country's flag image.

set :country_flags, Hash[
  Dir["public/images/flags/*.gif"].map do |name|
    [File.basename(name, ".gif").downcase,
     name.sub("public/", "")]
  end
]

#set :haml, escape_html: true

maxminddb = MaxMindDB.new("maxmind/GeoLite2-City.mmdb")

visit_store = VisitStoreMongo.new(mongo_uri)

helpers do
  # Convert "" into nil.

  def string_or_nil(val)
    (val && val.size > 0) ? val : nil
  end

  # Get the config, if any, for the given key string.

  def config_for_key(key)
    settings.config[key]
  end

  # Check that the page passed in is ok for the given config.

  def page_ok?(config, url)
    uri = URI.parse(url) rescue nil
    (uri.respond_to?(:host) && uri.host =~ config["host_re"] &&
      uri.respond_to?(:path) && uri.path !~ %r{^/b/}).tap do |result|
      if !result
        puts "Rejecting page #{url} for key #{config["key"]}"
      end
    end
  end

  # Return the flag image url for the given country_code, or nil if
  # there is no flag image.

  def flag_url(country_code)
    country_flag = settings.country_flags[country_code.downcase]
    if country_flag
      url(country_flag)
    end
  end
end

# / is just an empty page.  It isn't used by anything.

get "/" do
  haml :index
end

# This is the page requested by the widget.  It can have whatever name
# you want, as specified by settings.config[key]["name"].

get "/:name.js" do |name|
  key = params[:key]
  config = config_for_key(key)
  halt 404 unless config && config["name"] == name
  content_type :js
  last_modified File.stat("views/freedjit.js.erb").mtime
  erb(:"freedjit.js", locals: {key: key, http_root: url("/")})
end

get "/visit" do
  key = params[:key]
  config = config_for_key(key)

  session = {} # XXX

  # document.URL (url for the page containing the javascript)
  page = params[:page] || ""
  page.sub!(%r{://www\.}, "://")

  title = params[:title]

  # href scraped from the page's title html that links to the page.
  url = params[:url] || ""
  url.sub!(%r{://www\.}, "://")

  # document.referrer, i.e., page the user came from.
  referrer = params[:ref]

  ok = config && page_ok?(config, page) && page_ok?(config, url)

  if ok && !session[:ignore] && !config["excludes"].include?(request.ip)
    if !(session[:id] && session[:id].size == 16)
      session[:id] = "none" # "%.16x" % rand(1 << 64)
      new_visitor = true
    end

    geo = maxminddb.lookup(request.ip)

    visit = Visit.new(
       "id" => session[:id],
       "ip" => request.ip,
       "new_visitor" => new_visitor,
       "url" => url,
       "title" => string_or_nil(title),
       "city" => (geo.city.name rescue nil),
       "region" => (geo.subdivisions.first.name rescue nil),
       "country" => geo.country.name,
       "country_code" => geo.country.iso_code,
       "anonymous_proxy" => geo.traits.is_anonymous_proxy,
       "user_agent" => request.user_agent,
       "page" => page,
       "referrer" => string_or_nil(referrer))

    visit_store.save(key, visit)
  end

  content_type :json, charset: "utf-8"
  erb(:"visit.js", locals: {ok: ok})
end

get "/list" do
  key = params[:key]
  config = config_for_key(key)
  session = {} # XXX
  list = []
  if config
    id = session[:id]
    ip = request.ip
    visit_store.each_not(key, id, ip) do |v|
      list << v unless list.any? do |e|
        e.same_visitor?(v) && e.display_title == v.display_title
      end
      break if list.size == 6
    end
  end

  html = haml(:list, locals: {list: list})

  content_type :json, charset: "utf-8"
  erb(:"list.js", locals: {html: html, name: config["name"]})
end

get "/ignore" do
  if params[:password] == settings.password
    session[:ignore] = true
  else
    session.delete(:ignore)
  end
  "ok"
end

get "/clear" do
  if params[:password] == settings.password
    session.delete(:id)
  end
  "cleared"
end
