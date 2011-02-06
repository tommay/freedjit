require "thread"

class BoundedList
  def initialize(max)
    @max = max
    @list = []
    @mutex = Mutex.new
  end

  def add(value)
    @mutex.synchronize do
      @list << value
      @list.shift while @list.size > @max
    end
  end

  def get(n)
    @mutex.synchronize do
      @list[0..n]
    end
  end
end
