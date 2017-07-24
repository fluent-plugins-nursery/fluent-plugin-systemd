# frozen_string_literal: true
require "systemd/journal"
require "fluent/plugin/input"
require "fluent/plugin/systemd/pos_writer"

module Fluent
  module Plugin
    class SystemdInput < Input
      Fluent::Plugin.register_input("systemd", self)

      helpers :timer, :storage

      DEFAULT_STORAGE_TYPE = "local"

      config_param :path, :string, default: "/var/log/journal"
      config_param :filters, :array, default: []
      config_param :pos_file, :string, default: nil, deprecated: "Use <storage> section with `persistent: true' instead"
      config_param :read_from_head, :bool, default: false
      config_param :strip_underscores, :bool, default: false
      config_param :tag, :string

      config_section :storage do
        config_set_default :usage, "positions"
        config_set_default :@type, DEFAULT_STORAGE_TYPE
        config_set_default :persistent, false
      end

      def configure(conf)
        super
        @pos_storage = PosWriter.new(@pos_file, storage_create(usage: "positions"))
        @journal = nil
      end

      def start
        super
        @pos_storage.start
        timer_execute(:in_systemd_emit_worker, 1, &method(:run))
      end

      def shutdown
        @pos_storage.shutdown
        super
      end

      private

      def init_journal
        @journal = Systemd::Journal.new(path: @path)
        # make sure initial call to wait doesn't return :invalidate
        # see https://github.com/ledbettj/systemd-journal/issues/70
        @journal.wait(0)
        @journal.filter(*@filters)
        seek
        true
      rescue Systemd::JournalError => e
        log.warn("#{e.class}: #{e.message} retrying in 1s")
        false
      end

      def seek
        cursor = @pos_storage.get(:journal)
        seek_to(cursor || read_from)
      rescue Systemd::JournalError
        log.warn(
          "Could not seek to cursor #{cursor} found in pos file: #{@pos_storage.path}, " \
          "falling back to reading from #{read_from}",
        )
        seek_to(read_from)
      end

      # according to https://github.com/ledbettj/systemd-journal/issues/64#issuecomment-271056644
      # and https://bugs.freedesktop.org/show_bug.cgi?id=64614, after doing a seek(:tail),
      # you must move back in such a way that the next move_next will return the last
      # record
      def seek_to(pos)
        @journal.seek(pos)
        return if pos == :head
        if pos == :tail
          @journal.move(-2)
        else
          @journal.move(1)
        end
      end

      def read_from
        @read_from_head ? :head : :tail
      end

      def run
        return unless @journal || init_journal
        init_journal if @journal.wait(0) == :invalidate
        watch do |entry|
          emit(entry)
        end
      end

      def emit(entry)
        router.emit(@tag, Fluent::EventTime.from_time(entry.realtime_timestamp), formatted(entry))
      rescue Fluent::Plugin::Buffer::BufferOverflowError => e
        retries ||= 0
        raise e if retries > 10
        retries += 1
        sleep 1.5**retries + rand(0..3)
        retry
      rescue => e
        log.error("Exception emitting record: #{e}")
      end

      def formatted(entry)
        return entry.to_h unless @strip_underscores
        Hash[entry.to_h.map { |k, v| [k.gsub(/\A_+/, ""), v] }]
      end

      def watch
        while @journal.move_next
          yield @journal.current_entry
          @pos_storage.put(:journal, @journal.cursor)
        end
      end
    end
  end
end
