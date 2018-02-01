# frozen_string_literal: true
require "fluent/plugin/input"

module Fluent
  module Plugin
    class SystemdInput < Input
      class PosWriter
        def initialize(pos_file, storage)
          @path = pos_file
          @lock = Mutex.new
          @storage = storage
          @cursor = nil
          @written_cursor = nil
          setup
        end

        def get(key)
          @storage ? @storage.get(key) : @cursor
        end

        def put(key, cursor)
          return @storage.put(key, cursor) if @storage
          @lock.synchronize { @cursor = cursor }
        end

        def path
          @path || @storage.path
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
          if @storage.persistent
            migrate_to_storage
          elsif @path
            @cursor = read_legacy_pos if legacy_file?
            @storage = nil
          end
        end

        def legacy_file?
          @path && File.exist?(@path)
        end

        def read_legacy_pos
          IO.read(@path).chomp
        end

        def migrate_to_storage
          return unless legacy_file?
          @storage.put(:journal, read_legacy_pos)
          File.delete(@path)
          @path = nil
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
              file = File.open(@path, "w+", 0o644)
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
