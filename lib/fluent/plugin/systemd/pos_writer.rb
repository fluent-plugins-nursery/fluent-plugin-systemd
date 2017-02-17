require "fluent/plugin/input"

module Fluent
  module Plugin
    class SystemdInput < Input
      class PosWriter
        def initialize(pos_file)
          @path = pos_file
          @lock = Mutex.new
          @cursor = nil
          @written_cursor = nil
          setup
        end

        attr_reader :path

        def get(_)
          @cursor
        end

        def put(_, cursor)
          @lock.synchronize { @cursor = cursor }
        end

        def start
          return unless @path
          @running = true
          @thread = Thread.new(&method(:work))
        end

        def shutdown
          return unless @path
          @running = false
          @thread.join
          write_pos
        end

        private

        def setup
          return unless @path && File.exist?(@path)
          @cursor = IO.read(@path).chomp
        end

        def work
          while @running
            write_pos
            sleep 1
          end
        end

        def write_pos
          @lock.synchronize do
            if @written_cursor != @cursor
              file = File.open(@path, "w+", 0644)
              file.print @cursor
              file.close
              @written_cursor = @cursor
            end
          end
        end
      end
    end
  end
end
