# rubocop:disable Style/FrozenStringLiteralComment
require_relative "../helper"
require_relative "./systemd/test_entry_mutator"
require "tempfile"
require "fluent/test/driver/input"
require "fluent/plugin/in_systemd"

class SystemdInputTest < Test::Unit::TestCase # rubocop:disable Metrics/ClassLength
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
      EntryTestData::EXPECTED[:fields_strip_underscores],
    ],
    fields_lowercase: [
      @base_config + %(
        <entry>
          fields_lowercase true
        </entry>
      ),
      EntryTestData::EXPECTED[:fields_lowercase],
    ],
    field_map: [
      @base_config + %(
        <entry>
          field_map #{EntryTestData::FIELD_MAP_JSON}
        </entry>
      ),
      EntryTestData::EXPECTED[:field_map],
    ],
    field_map_strict: [
      @base_config + %(
        <entry>
          field_map #{EntryTestData::FIELD_MAP_JSON}
          field_map_strict true
        </entry>
      ),
      EntryTestData::EXPECTED[:field_map_strict],
    ],
  }

  def setup
    Fluent::Test.setup

    @base_config = %(
      tag test
      path test/fixture
    )

    @badmsg_config = %(
      tag test
      path test/fixture/corrupt
      read_from_head true
    )

    # deprecated
    @strip_config = base_config + %(
      strip_underscores true
    )

    pos_dir = Dir.mktmpdir("posdir")

    @pos_path = "#{pos_dir}/foo.pos"

    @pos_config = base_config + %(
      pos_file #{@pos_path}
    )

    @storage_path = File.join(pos_dir.to_s, "storage.json")

    @head_config = @pos_config + %(
      read_from_head true
    )

    @filter_config = @head_config + %(
      filters [{ "_SYSTEMD_UNIT": "systemd-journald.service" }]
    )

    @tail_config = @pos_config + %(
      read_from_head false
    )

    @not_present_config = %(
      tag test
      path test/not_a_real_path
    )
  end

  attr_reader :journal, :base_config, :pos_path, :pos_config, :head_config,
    :filter_config, :strip_config, :tail_config, :not_present_config,
    :badmsg_config, :storage_path

  def create_driver(config)
    Fluent::Test::Driver::Input.new(Fluent::Plugin::SystemdInput).configure(config)
  end

  def test_configure_requires_tag
    assert_raise Fluent::ConfigError do
      create_driver("")
    end
  end

  def test_configuring_tag
    d = create_driver(base_config)
    assert_equal d.instance.tag, "test"
  end

  def test_reading_from_the_journal_tail
    d = create_driver(base_config)
    expected = [[
      "test",
      1_364_519_243,
      EntryTestData::EXPECTED[:no_transform],
    ],]
    d.run(expect_emits: 1)
    assert_equal(expected, d.events)
  end

  data(@entry_tests)
  def test_reading_from_the_journal_tail_mutate_entry(data)
    conf, expect = data
    d = create_driver(conf)
    expected = [[
      "test",
      1_364_519_243,
      expect,
    ],]
    d.run(expect_emits: 1)
    assert_equal(expected, d.events)
  end

  # deprecated config option for backwards compatibility
  def test_reading_from_the_journal_tail_with_strip_underscores_legacy
    d = create_driver(strip_config)
    expected = [[
      "test",
      1_364_519_243,
      EntryTestData::EXPECTED[:fields_strip_underscores],
    ],]
    d.run(expect_emits: 1)
    assert_equal(expected, d.events)
  end

  def test_storage_file_is_written
    storage_config = config_element("ROOT", "", {
                                      "tag" => "test",
                                      "path" => "test/fixture",
                                      "@id" => "test-01",
                                    }, [
                                      config_element("storage", "",
                                        "@type"      => "local",
                                        "persistent" => true,
                                        "path"       => @storage_path),
                                    ])

    d = create_driver(storage_config)
    d.run(expect_emits: 1)
    storage = JSON.parse(File.read(storage_path))
    result = storage["journal"]
    assert_equal result, "s=add4782f78ca4b6e84aa88d34e5b4a9d;i=1cd;b=4737ffc504774b3ba67020bc947f1bc0;m=42f2dd;t=4d905e4cd5a92;x=25b3f86ff2774ac4" # rubocop:disable Metrics/LineLength
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

    def emit_event_stream(tag, es)
      unless @called > 1
        @called += 1
        fail Fluent::Plugin::Buffer::BufferOverflowError, "buffer space has too many data"
      end

      super
    end
  end

  def test_backoff_on_buffer_error
    d = BufferErrorDriver.new(Fluent::Plugin::SystemdInput).configure(base_config)
    d.run(expect_emits: 1)
  end

  def test_reading_with_filters
    d = create_driver(filter_config)
    d.end_if do
      d.events.size >= 3
    end
    d.run(timeout: 5)
    assert_equal 3, d.events.size
  end

  def test_reading_from_a_pos
    file = File.open(pos_path, "w+")
    file.print "s=add4782f78ca4b6e84aa88d34e5b4a9d;i=13f;b=4737ffc504774b3ba67020bc947f1bc0;m=ffadd;t=4d905e49a6291;x=9a11dd9ffee96e9f" # rubocop:disable Metrics/LineLength
    file.close
    d = create_driver(head_config)
    d.end_if do
      d.events.size >= 142
    end
    d.run(timeout: 5)
    assert_equal 142, d.events.size
  end

  def test_reading_from_an_invalid_pos # rubocop:disable Metrics/AbcSize
    file = File.open(pos_path, "w+")
    file.print "thisisinvalid"
    file.close

    # It continues as if the pos file did not exist
    d = create_driver(head_config)
    d.end_if do
      d.events.size >= 461
    end
    d.run(timeout: 5)
    assert_equal 461, d.events.size
    assert_match(
      "Could not seek to cursor thisisinvalid found in pos file: #{pos_path}, falling back to reading from head",
      d.logs.last,
    )
  end

  def test_reading_from_the_journal_tail_explicit_setting
    d = create_driver(tail_config)
    expected = [[
      "test",
      1_364_519_243,
      EntryTestData::EXPECTED[:no_transform],
    ],]
    d.run(expect_emits: 1)
    assert_equal(expected, d.events)
  end

  def test_journal_not_present
    d = create_driver(not_present_config)
    d.end_if { d.logs.size > 1 }
    d.run(timeout: 5)
    assert_match "Systemd::JournalError: No such file or directory retrying in 1s", d.logs.last
  end

  def test_continue_on_bad_message
    d = create_driver(badmsg_config)
    d.run(expect_emits: 460)
    assert_equal 460, d.events.size
    assert_equal 0, d.error_events.size
  end
end
