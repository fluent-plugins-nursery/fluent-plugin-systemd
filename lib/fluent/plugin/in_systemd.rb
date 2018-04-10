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

    def configure(conf)
      super
      @pos_writer = PosWriter.new(@pos_file)
    end

    def start
      super
      @running = true
      @pos_writer.start
      @thread = Thread.new(&method(:run))
    end

    def shutdown
      super
      @running = false
      @thread.join
      @pos_writer.shutdown
    end

    private

    def init_journal
      @journal.close if @journal
      @journal = Systemd::Journal.new(path: @path)
      # make sure initial call to wait doesn't return :invalidate
      # see https://github.com/ledbettj/systemd-journal/issues/70
      @journal.wait(0)
      @journal.filter(*@filters)
      seek
    end

    def seek
      seek_to(@pos_writer.cursor || read_from)
    rescue Systemd::JournalError
      log.warn("Could not seek to cursor #{@pos_writer.cursor} found in pos file: #{@pos_writer.path}")
      seek_to(read_from)
    end

    # according to https://github.com/ledbettj/systemd-journal/issues/64#issuecomment-271056644
    # and https://bugs.freedesktop.org/show_bug.cgi?id=64614, after doing a seek(:tail),
    # you must move back in such a way that the next move_next will return the last
    # record
    def seek_to(pos)
      @journal.seek(pos)
      return unless pos == :tail
      @journal.move(-2)
    end

    def read_from
      @read_from_head ? :head : :tail
    end

    def run
      init_journal
      Thread.current.abort_on_exception = true
      watch do |entry|
        begin
          router.emit(@tag, entry.realtime_timestamp.to_i, formatted(entry))
        rescue Exception => e
          log.error("Exception emitting record: #{e}")
        end
      end
    end

    def formatted(entry)
      return entry.to_h unless @strip_underscores
      Hash[entry.to_h.map { |k, v| [k.gsub(/\A_+/, ""), v] }]
    end

    def watch
      while @running
        init_journal if @journal.wait(0) == :invalidate
        while @journal.move_next && @running
          begin
            yield @journal.current_entry
          rescue Systemd::JournalError => e
            log.warn("Error Parsing Journal: #{e.class}: #{e.message}")
            next
          end
          @pos_writer.update(@journal.cursor)
        end
        # prevent a loop of death
        sleep 1
      end
    end
  end
end
