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
