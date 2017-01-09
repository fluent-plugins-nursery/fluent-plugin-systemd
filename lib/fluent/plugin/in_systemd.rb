require "systemd/journal"
require "fluent/input"
require "fluent/plugin/systemd/pos_writer"

module Fluent
  class SystemdInput < Input
    Fluent::Plugin.register_input("systemd", self)

    config_param :path, :string, default: "/var/log/journal"
    config_param :filters, :array, default: []
    config_param :pos_file, :string, default: nil
    config_param :read_from_head, :bool, default: false
    config_param :strip_underscores, :bool, default: false
    config_param :tag, :string

    attr_reader :tag

    def configure(conf)
      super
      @pos_writer = PosWriter.new(conf["pos_file"])
      @journal = Systemd::Journal.new(path: path)
      journal.filter(*filters)
      seek
    end

    def start
      super
      @running = true
      pos_writer.start
      @thread = Thread.new(&method(:run))
    end

    def shutdown
      super
      @running = false
      @thread.join
      pos_writer.shutdown
    end

    private

    attr_reader :journal, :running, :lock, :cursor, :path, :pos_writer, :strip_underscores, :read_from_head

    def seek
      journal.seek(@pos_writer.cursor || read_from)
    rescue Systemd::JournalError
      log.warn("Could not seek to cursor #{@pos_writer.cursor} found in pos file: #{@pos_writer.path}")
      journal.seek(read_from)
    end

    def read_from
      read_from_head ? :head : :tail
    end

    def run
      Thread.current.abort_on_exception = true
      watch do |entry|
        begin
          router.emit(tag, entry.realtime_timestamp.to_i, formatted(entry))
        rescue => e
          log.error("Exception emitting record: #{e}")
        end
      end
    end

    def formatted(entry)
      return entry.to_h unless strip_underscores
      Hash[entry.to_h.map { |k, v| [k.gsub(/\A_+/, ""), v] }]
    end

    def watch
      while running
        next unless journal.wait(1_000_000)
        while journal.move_next && running
          yield journal.current_entry
          pos_writer.update(journal.cursor)
        end
      end
    end
  end
end
