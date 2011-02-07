class Visit
  attr_reader :id, :ip, :url, :title, :time

  def initialize(id, ip, new_visitor, url, title)
    @id = id
    @ip = ip
    @new_visitor = new_visitor
    @url = url
    @title = title
    @time = Time.now.to_i
  end

  def new?
    @new_visitor
  end

  def where
    @ip
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
end
