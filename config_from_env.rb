# Get config settings from environment variables.  On heroku these
# can be set with "heroku config:set var=val".

# key: For multi-user/multi-site support, each user/site having a
# different key.  When configuring from environment variables there is
# only one key.  A request with an unknown key gives a 404 or an empty
# list.  Note that the key is in the html/javascript that makes the
# requests so it's not secure, but it works with only one host, passed
# in from the page's url and title, so it's not too bad.

# host_re:

# The blog that matches the key, e.g., "xyz.blogspot".  Only requests
# from this blog are honored by /visit, as determined by host of the
# url parameter passed in the request.  A regexp is used to match
# variations before and after the blog name, e.g., .com, .ca,.co.uk,
# www., etc.

# Name is the name recognized for fetching the main javascript file,
# i.e., /<name>.js.

# F_EXCLUDES is a colon-separated list of ip addresses to not track as
# visitors.

class ConfigFromEnv
  def self.get_config
    key = ENV["F_KEY"]
    {
      key => {
        "key" => key,
        "host" => ENV["F_HOST"],
        "name" => ENV["F_NAME"],
        "excludes" => ENV["F_EXCLUDES"].split(":"),
      }
    }
  end
end
