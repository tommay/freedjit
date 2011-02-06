class Visit
  attr_reader :id, :ip, :title, :url, :time

  def initialize(id, ip, title, url)
    @id = id
    @ip = ip
    @title = title
    @url = url
    @time = Time.now.to_i
  end

  def when
    delta = Time.now.to_i - @time
    if delta < 60
      return ago(delta, "second")
    end
    delta /= 60
    if delta < 60
      return ago(delta, "minute")
    end
    delta /= 60
    if delta < 24
      return ago(delta, "hour")
    end
    ago(delta, "day")
  end

  def ago(delta, unit)
    "#{delta} #{unit}#{delta == 1 ? "" : "s"} ago"
  end
end
