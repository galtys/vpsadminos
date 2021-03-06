module OsCtl::Lib
  # Interface to system processes, reading information from `/proc`
  class OsProcess
    attr_reader :pid, :ppid, :nspid, :real_uid, :name

    # @param pid [Integer]
    def initialize(pid)
      @pid = pid
      parse_status
    end

    # @return [OsProcess]
    def parent
      self.class.new(ppid)
    end

    # @return [OsProcess]
    def grandparent
      parent.parent
    end

    # Return PID as seen in the container's PID namespace
    # @return [Integer]
    def ctpid
      nspid[1]
    end

    protected
    def parse_status
      File.open(File.join('/proc', pid.to_s, 'status'), 'r') do |f|
        f.each_line do |line|
          parts = line.split(':')
          next if parts.count != 2

          k = parts[0].strip
          v = parts[1].strip

          case k
          when 'PPid'
            @ppid = v.to_i

          when 'NSpid'
            @nspid = v.split.map(&:to_i)

          when 'Uid'
            @real_uid, @effective_uid, @saved_uid, @fs_uid = v.split.map(&:to_i)

          when 'Name'
            @name = v
          end
        end
      end
    end
  end
end
