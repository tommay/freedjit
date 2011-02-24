class Visit
  attr_reader :id, :ip, :url, :title, :time, :city, :region,
    :country, :country_code

  def initialize(args)
    @id = args[:id]
    @ip = args[:ip]
    @new_visitor = args[:new_visitor]
    @url = args[:url]
    @title = args[:title]
    @city = args[:city]
    @region = args[:region]
    @country = args[:country]
    @country_code = args[:country_code]
    @time = args[:time] || Time.now.to_i
  end

  def new?
    @new_visitor
  end

  def where
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
      result << @country
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
    if url && url =~ %r{\?updated-min=(\d{4})}
      $1
    elsif title
      # Get rid of the blog title (everything before the first colon), if any
      result = title.sub(/^.*?:\s*/, "")
      if url && url =~ %r{/search/label/}
        result = ["tag", "<span class='visit-category'>#{result}</span>"]
      end
      result
    else
      "a page"
    end
  end
end
