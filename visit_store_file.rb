# Store visits to a file.

require "bounded_list"

class VisitStoreFile
  def initialize(filename)
    @visits = BoundedList.new(1000)
    @log = File.open(filename, "a")
    @mutex = Mutex.new

    File.open(filename) do |file|
      file.each do |line|
        s = line.chomp.split(/\|/) rescue next

        keys = [:time, :id, :new_visitor, :ip, :url, :title,
                :city, :region, :country, :country_code, :user_agent]

        v = {}
        keys.each_with_index do |key, i|
          v[key] = s[i]
        end

        v[:new_visitor] = v[:new_visitor] == "t"
        v[:time] = v[:time].to_i

        @visits.add(Visit.new(v))
      end
    end
  end

  def save(visit, request)
    @visits.add(visit)

    @mutex.synchronize do
      @log.write("#{visit.time}|#{visit.id}|#{visit.new? ? "t" : "f"}|#{visit.ip}|#{visit.url}|#{visit.title}|#{visit.city}|#{visit.region}|#{visit.country}|#{visit.country_code}|#{request.user_agent}\n")
      @log.flush
    end
  end

  def each_not(id, ip, &block)
    @visits.all.select{|v| id ? v.id != id : v.ip != ip}.each(&block)
  end
end
