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

  def all
    @mutex.synchronize do
      @list.clone
    end
  end
end
