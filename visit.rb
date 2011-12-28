require "uri"

class Visit
  attr_reader :id, :ip, :url, :title, :city, :region, :country,
    :country_code, :user_agent, :page, :referrer, :time

  def initialize(args)
    @id = args["id"]
    @ip = args["ip"]
    @new_visitor = args["new_visitor"]
    @url = args["url"]
    @title = args["title"]
    @city = args["city"]
    @region = args["region"]
    @country = args["country"]
    @country_code = args["country_code"]
    @user_agent= args["user_agent"]
    @page = args["page"]
    @referrer = args["referrer"]
    @time = args["time"] || Time.now.to_i
  end

  def to_hash
    {
      "id" => @id,
      "ip" => @ip,
      "new_visitor" => @new_visitor,
      "url" => @url,
      "title" => @title,
      "city" => @city,
      "region" => @region,
      "country" => @country,
      "country_code" => @country_code,
      "user_agent" => @user_agent,
      "page" => @page,
      "referrer" => @referrer,
      "time" => @time,
    }
  end

  def same_visitor?(other)
    if self.new? || other.new?
      self.ip == other.ip
    else
      self.id == other.id
    end
  end

  def new?
    @new_visitor
  end

  def where
    return nil if [ "A1", "A2", "O2" ].include?(@country_code)
    result = ""
    if @city
      result << @city
    end
    if ["US", "CA"].include?(@country_code) && @region
      result << ", " if result != ""
      result << @region
    end
    if @country
      result << ", " if result != ""
      result << case @country
        when /(.*), (.*)/
          if $1 == "Taiwan"
            $1
          else
            "#{$2} #{$1}"
          end
        else
          @country
        end
    end
    if result == ""
      result = nil
    end
    result
  end

  def flag
    "#{@iso_country}.png" if @iso_country
  end

  def when
    seconds = Time.now.to_i - @time
    return ago(seconds, "second") if seconds < 60
    minutes = seconds / 60
    return ago(minutes, "minute") if minutes < 60
    hours = minutes / 60
    return ago(hours, "hour") if hours < 24
    days = hours / 24
    return ago(days, "day") if days < 30
    months = seconds / 2628000
    return ago(months, "month") if months < 12
    years = days / 365
    return ago(years, "year")
  end

  def ago(delta, unit)
    "#{delta} #{unit}#{delta == 1 ? "" : "s"} ago"
  end

  def display_title
    case
    when title
      # Get rid of the blog title (everything before the first colon), if any
      result = title.sub(/^.*?:\s*/, "")
      if url && url =~ %r{/search/label/}
        result = ["posts tagged", result]
      end
      result
    when url && url =~ %r{\?updated-min=(\d{4})}
      $1
    else
      "a page"
    end
  end

  @@whitelist_params = [
    "updated-min", "updated-max", "max-results", "reverse-paginate"
  ]

  def link_url
    if url
      u = URI.parse(url)
      klass = (u.scheme == "https") ? URI::HTTPS : URI::HTTP;
      # Don't include the fragment.
      klass.build(:host => u.host, :port => u.port, :path => u.path,
                  :query => sanitize_query(u.query))
    end
  end

  def sanitize_query(q)
    if q
      q = q.split("&").map do |p|
        param = p.split("=")
        if @@whitelist_params.include?(param.first)
          if param.first == "max-results"
            "max-results=3"
          else
            param.join("=")
          end
        else
          nil
        end
      end.compact
    else
      q = []
    end
    q << "fav=r"
    q = q.join("&")
    q == "" ? nil : q
  end
end
