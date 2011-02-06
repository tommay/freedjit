require "thread"

class BoundedList
  def initialize(max)
    @max = max
    @list = []
    @mutex = Mutex.new
  end

  def add(value)
    @mutex.synchronize do
      @list.unshift(value)
      @list = @list[0..@max-1]
    end
  end

  def get(n)
    @mutex.synchronize do
      @list[0..n-1]
    end
  end
end
