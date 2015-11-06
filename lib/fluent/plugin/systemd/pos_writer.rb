module Fluent
  class SystemdInput < Input
    class PosWriter
      def initialize(pos_file)
        @path = pos_file
        setup
      end

      attr_reader :cursor

      def start
        return unless path
        @running = true
        @thread = Thread.new(&method(:work))
      end

      def shutdown
        return unless path
        @running = false
        thread.join
        write_pos
      end

      def update(c)
        return unless path
        lock.synchronize { @cursor = c }
      end

      private

      attr_reader :path, :lock, :thread, :running

      def setup
        return unless path
        @lock = Mutex.new
        @cursor = IO.read(path).chomp if File.exist?(path)
      end

      def work
        while running
          write_pos
          sleep 1
        end
      end

      def write_pos
        lock.synchronize do
          if @written_cursor != cursor
            file = File.open(path, 'w+')
            file.print cursor
            file.close
            @written_cursor = cursor
          end
        end
      end
    end
  end
end
