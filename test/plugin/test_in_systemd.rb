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

require_relative '../helper'
require_relative './systemd/test_entry_mutator'
require 'tempfile'
require 'fluent/test/driver/input'
require 'fluent/plugin/in_systemd'

class SystemdInputTest < Test::Unit::TestCase
  include Fluent::Test::Helpers

  @base_config = %(
    tag test
    path test/fixture
  )
  # entry test data in the form:
  # { test_name: [plugin_config, expected_entry], ... }
  @entry_tests = {
    fields_strip_underscores: [
      @base_config + %(
        <entry>
          fields_strip_underscores true
        </entry>
      ),
      EntryTestData::EXPECTED[:fields_strip_underscores]
    ],
    fields_lowercase: [
      @base_config + %(
        <entry>
          fields_lowercase true
        </entry>
      ),
      EntryTestData::EXPECTED[:fields_lowercase]
    ],
    field_map: [
      @base_config + %(
        <entry>
          field_map #{EntryTestData::FIELD_MAP_JSON}
        </entry>
      ),
      EntryTestData::EXPECTED[:field_map]
    ],
    field_map_strict: [
      @base_config + %(
        <entry>
          field_map #{EntryTestData::FIELD_MAP_JSON}
          field_map_strict true
        </entry>
      ),
      EntryTestData::EXPECTED[:field_map_strict]
    ]
  }

  def setup
    Fluent::Test.setup

    @base_config = %(
      tag test
      path test/fixture
    )

    @storage_path = File.join(Dir.mktmpdir('pos_dir'), 'storage.json')

    @storage_config = @base_config + %(
      <storage>
        @type local
        persistent true
        path #{storage_path}
      </storage>
    )

    @head_config = @storage_config + %(
      read_from_head true
    )

    @filter_config = @head_config + %(
      filters [{ "_SYSTEMD_UNIT": "systemd-journald.service" }]
    )

    @matches_config = @head_config + %(
      matches [{ "_SYSTEMD_UNIT": "systemd-journald.service" }]
    )

    @tail_config = @storage_config + %(
      read_from_head false
    )

    @not_present_config = %(
      tag test
      path test/not_a_real_path
    )

    @corrupt_entries_config = %(
       tag test
       path test/fixture/corrupt
       read_from_head true
    )
  end

  attr_reader :journal, :base_config, :head_config,
              :matches_config, :filter_config, :tail_config, :not_present_config,
              :storage_path, :storage_config, :corrupt_entries_config

  def create_driver(config)
    Fluent::Test::Driver::Input.new(Fluent::Plugin::SystemdInput).configure(config)
  end

  def read_pos
    JSON.parse(File.read(storage_path))['journal']
  end

  def write_pos(pos)
    File.write(storage_path, JSON.dump(journal: pos))
  end

  def test_configure_requires_tag
    assert_raise Fluent::ConfigError do
      create_driver('')
    end
  end

  def test_configuring_tag
    d = create_driver(base_config)
    assert_equal d.instance.tag, 'test'
  end

  def test_reading_from_the_journal_tail
    d = create_driver(base_config)
    expected = [[
      'test',
      1_364_519_243,
      EntryTestData::EXPECTED[:no_transform]
    ]]
    d.run(expect_emits: 1)
    assert_equal(expected, d.events)
  end

  data(@entry_tests)
  def test_reading_from_the_journal_tail_mutate_entry(data)
    conf, expect = data
    d = create_driver(conf)
    expected = [[
      'test',
      1_364_519_243,
      expect
    ]]
    d.run(expect_emits: 1)
    assert_equal(expected, d.events)
  end

  def test_storage_file_is_written
    d = create_driver(storage_config)
    d.run(expect_emits: 1)
    assert_equal 's=add4782f78ca4b6e84aa88d34e5b4a9d;i=1cd;b=4737ffc504774b3ba67020bc947f1bc0;m=42f2dd;t=4d905e4cd5a92;x=25b3f86ff2774ac4', read_pos
  end

  def test_reading_from_head
    d = create_driver(head_config)
    d.end_if do
      d.events.size >= 461
    end
    d.run(timeout: 5)
    assert_equal 461, d.events.size
  end

  class BufferErrorDriver < Fluent::Test::Driver::Input
    def initialize(klass, opts: {}, &block)
      @called = 0
      super
    end

    def emit_event_stream(tag, event_stream)
      unless @called > 1
        @called += 1
        raise Fluent::Plugin::Buffer::BufferOverflowError, 'buffer space has too many data'
      end

      super
    end
  end

  def test_backoff_on_buffer_error
    d = BufferErrorDriver.new(Fluent::Plugin::SystemdInput).configure(base_config)
    d.run(expect_emits: 1)
  end

  # deprecated and replaced with matches
  def test_reading_with_filters
    d = create_driver(filter_config)
    d.end_if do
      d.events.size >= 3
    end
    d.run(timeout: 5)
    assert_equal 3, d.events.size
  end

  def test_reading_with_matches
    d = create_driver(matches_config)
    d.end_if do
      d.events.size >= 3
    end
    d.run(timeout: 5)
    assert_equal 3, d.events.size
  end

  def test_reading_from_a_pos
    write_pos 's=add4782f78ca4b6e84aa88d34e5b4a9d;i=13f;b=4737ffc504774b3ba67020bc947f1bc0;m=ffadd;t=4d905e49a6291;x=9a11dd9ffee96e9f'
    d = create_driver(head_config)
    d.end_if do
      d.events.size >= 142
    end
    d.run(timeout: 5)
    assert_equal 142, d.events.size
  end

  def test_reading_from_an_invalid_pos
    write_pos 'thisisinvalid'

    # It continues as if the pos file did not exist
    d = create_driver(head_config)
    d.end_if do
      d.events.size >= 461
    end
    d.run(timeout: 5)
    assert_equal 461, d.events.size
    assert_match(
      "Could not seek to cursor thisisinvalid found in position file: #{storage_path}, falling back to reading from head",
      d.logs.last
    )
  end

  def test_reading_from_the_journal_tail_explicit_setting
    d = create_driver(tail_config)
    expected = [[
      'test',
      1_364_519_243,
      EntryTestData::EXPECTED[:no_transform]
    ]]
    d.run(expect_emits: 1)
    assert_equal(expected, d.events)
  end

  def test_journal_not_present
    d = create_driver(not_present_config)
    d.end_if { d.logs.size > 1 }
    d.run(timeout: 5)
    assert_match 'Systemd::JournalError: No such file or directory retrying in 1s', d.logs.last
  end

  def test_reading_from_a_journal_with_corrupted_entries
    # One corrupted entry exists in 461 entries. (The 3rd entry is corrupted.)
    d = create_driver(corrupt_entries_config)
    d.run(expect_emits: 460)
    # Since libsystemd v250, it can read this corrupted record.
    assert { d.events.size == 460 or d.events.size == 461 }
  end
end
