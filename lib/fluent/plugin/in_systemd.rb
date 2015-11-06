require 'systemd/journal'
require 'fluent/plugin/systemd/pos_writer'

module Fluent
  class SystemdInput < Input
    Fluent::Plugin.register_input('systemd', self)

    config_param :path, :string, default: '/var/log/journal'
    config_param :filters, :array, default: []
    config_param :pos_file, :string, default: nil
    config_param :read_from_head, :bool, default: false
    config_param :tag, :string

    attr_reader :tag

    def configure(conf)
      super
      @pos_writer = PosWriter.new(conf['pos_file'])
      @journal = Systemd::Journal.new(path: path)
      journal.filter(*filters)
      read_from = @pos_writer.cursor || (conf['read_from_head'] ? :head : :tail)
      journal.seek(read_from)
    end

    def start
      super
      @running = true
      pos_writer.start
      @thread = Thread.new(&method(:run))
    end

    def shutdown
      @running = false
      @thread.join
      pos_writer.shutdown
    end

    private

    attr_reader :journal, :running, :lock, :cursor, :path, :pos_writer

    def run
      watch do |entry|
        router.emit(tag, entry.realtime_timestamp.to_i, formatted(entry))
      end
    end

    def formatted(entry)
      entry.to_h
    end

    def watch
      while running
        next unless journal.wait
        while journal.move_next && running
          yield journal.current_entry
          pos_writer.update(journal.cursor)
        end
      end
    end
  end
end
