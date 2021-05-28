# frozen_string_literal: true

#   Copyright 2015-2018 Edward Robinson
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

require 'systemd/journal'
require 'fluent/plugin/input'
require 'fluent/plugin/systemd/entry_mutator'

module Fluent
  module Plugin
    # Fluentd plugin for reading from the systemd journal
    class SystemdInput < Input # rubocop:disable Metrics/ClassLength
      Fluent::Plugin.register_input('systemd', self)

      helpers :timer, :storage

      DEFAULT_STORAGE_TYPE = 'local'

      config_param :path, :string, default: '/var/log/journal'
      config_param :filters, :array, default: [], deprecated: 'filters has been renamed as matches'
      config_param :matches, :array, default: nil
      config_param :read_from_head, :bool, default: false
      config_param :tag, :string

      config_section :storage do
        config_set_default :usage, 'positions'
        config_set_default :@type, DEFAULT_STORAGE_TYPE
        config_set_default :persistent, false
      end

      config_section :entry, param_name: 'entry_opts', required: false, multi: false do
        config_param :field_map, :hash, default: {}
        config_param :field_map_strict, :bool, default: false
        config_param :fields_strip_underscores, :bool, default: false
        config_param :fields_lowercase, :bool, default: false
      end

      def configure(conf)
        super
        @journal = nil
        @pos_storage = storage_create(usage: 'positions')
        @mutator = SystemdEntryMutator.new(**@entry_opts.to_h)
        @mutator.warnings.each { |warning| log.warn(warning) }
      end

      def start
        super
        @running = true
        timer_execute(:in_systemd_emit_worker, 1, &method(:run))
      end

      def shutdown
        @running = false
        @journal&.close
        @journal = nil
        @pos_storage = nil
        @mutator = nil
        super
      end

      private

      def init_journal
        # TODO: ruby 2.3
        @journal.close if @journal # rubocop:disable Style/SafeNavigation
        @journal = Systemd::Journal.new(path: @path)
        @journal.filter(*(@matches || @filters))
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
          "Could not seek to cursor #{cursor} found in position file: #{@pos_storage.path}, " \
          "falling back to reading from #{read_from}"
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
      rescue => e # rubocop:disable Style/RescueStandardError
        log.error("Exception emitting record: #{e}")
      end

      def formatted(entry)
        @mutator.run(entry)
      end

      def watch(&block)
        yield_current_entry(&block) while @running && @journal.move_next
      rescue Systemd::JournalError => e
        log.warn("Error moving to next Journal entry: #{e.class}: #{e.message}")
      end

      def yield_current_entry
        yield @journal.current_entry
        @pos_storage.put(:journal, @journal.cursor)
      rescue Systemd::JournalError => e
        log.warn("Error reading from Journal: #{e.class}: #{e.message}")
      end
    end
  end
end
