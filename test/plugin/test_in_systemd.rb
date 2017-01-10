require_relative "../helper"
require "tempfile"
require "fluent/plugin/in_systemd"

class SystemdInputTest < Test::Unit::TestCase # rubocop:disable Metrics/ClassLength

  def setup
    Fluent::Test.setup

    @base_config = %(
      tag test
      path test/fixture
    )

    @strip_config = base_config + %(
      strip_underscores true
    )

    pos_dir = Dir.mktmpdir("posdir")

    @pos_path = "#{pos_dir}/foo.pos"

    @pos_config = base_config + %(
      pos_file #{@pos_path}
    )

    @head_config = @pos_config + %(
      read_from_head true
    )

    @filter_config = @head_config + %(
      filters [{ "_SYSTEMD_UNIT": "systemd-journald.service" }]
    )

    @tail_config = @pos_config + %(
      read_from_head false
    )
  end

  attr_reader :journal, :base_config, :pos_path, :pos_config, :head_config, :filter_config, :strip_config, :tail_config

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
      "_UID" => "0",
      "_GID" => "0",
      "_BOOT_ID" => "4737ffc504774b3ba67020bc947f1bc0",
      "_MACHINE_ID" => "bb9d0a52a41243829ecd729b40ac0bce",
      "_HOSTNAME" => "arch",
      "PRIORITY" => "5",
      "_TRANSPORT" => "syslog",
      "SYSLOG_FACILITY" => "10",
      "SYSLOG_IDENTIFIER" => "login",
      "_PID" => "141",
      "_COMM" => "login",
      "_EXE" => "/bin/login",
      "_AUDIT_SESSION" => "1",
      "_AUDIT_LOGINUID" => "0",
      "MESSAGE" => "ROOT LOGIN ON tty1",
      "_CMDLINE" => "login -- root      ",
      "_SYSTEMD_CGROUP" => "/user/root/1",
      "_SYSTEMD_SESSION" => "1",
      "_SYSTEMD_OWNER_UID" => "0",
      "_SOURCE_REALTIME_TIMESTAMP" => "1364519243563178",
    ]]
    d.run(expect_emits: 1)
    assert_equal(expected, d.events)
  end

  def test_reading_from_the_journal_tail_with_strip_underscores
    d = create_driver(strip_config)
    expected = [[
      "test",
      1_364_519_243,
      "UID" => "0",
      "GID" => "0",
      "BOOT_ID" => "4737ffc504774b3ba67020bc947f1bc0",
      "MACHINE_ID" => "bb9d0a52a41243829ecd729b40ac0bce",
      "HOSTNAME" => "arch",
      "PRIORITY" => "5",
      "TRANSPORT" => "syslog",
      "SYSLOG_FACILITY" => "10",
      "SYSLOG_IDENTIFIER" => "login",
      "PID" => "141",
      "COMM" => "login",
      "EXE" => "/bin/login",
      "AUDIT_SESSION" => "1",
      "AUDIT_LOGINUID" => "0",
      "MESSAGE" => "ROOT LOGIN ON tty1",
      "CMDLINE" => "login -- root      ",
      "SYSTEMD_CGROUP" => "/user/root/1",
      "SYSTEMD_SESSION" => "1",
      "SYSTEMD_OWNER_UID" => "0",
      "SOURCE_REALTIME_TIMESTAMP" => "1364519243563178",
    ]]
    d.run(expect_emits: 1)
    assert_equal(expected, d.events)
  end


  def test_pos_file_is_written
    d = create_driver(pos_config)
    d.run(expect_emits: 1)
    assert_equal File.read(pos_path), "s=add4782f78ca4b6e84aa88d34e5b4a9d;i=1cd;b=4737ffc504774b3ba67020bc947f1bc0;m=42f2dd;t=4d905e4cd5a92;x=25b3f86ff2774ac4" # rubocop:disable Metrics/LineLength
  end

  def test_reading_from_head
    d = create_driver(head_config)
    d.run(expect_emits: 1)
    assert_equal 461, d.events.size
  end

  def test_reading_with_filters
    d = create_driver(filter_config)
    d.run(expect_emits: 1)
    assert_equal 3, d.events.size
  end

  def test_reading_from_a_pos
    file = File.open(pos_path, "w+")
    file.print "s=add4782f78ca4b6e84aa88d34e5b4a9d;i=13f;b=4737ffc504774b3ba67020bc947f1bc0;m=ffadd;t=4d905e49a6291;x=9a11dd9ffee96e9f" # rubocop:disable Metrics/LineLength
    file.close
    d = create_driver(head_config)
    d.run(expect_emits: 1)
    assert_equal 143, d.events.size
  end

  def test_reading_from_an_invalid_pos # rubocop:disable Metrics/AbcSize
    file = File.open(pos_path, "w+")
    file.print "thisisinvalid"
    file.close

    # It continues as if the pos file did not exist
    d = create_driver(head_config)
    d.run(expect_emits: 1)
    assert_equal 461, d.events.size
  end

  def test_reading_from_the_journal_tail_explicit_setting
    d = create_driver(tail_config)
    expected = [[
      "test",
      1_364_519_243,
      "_UID" => "0",
      "_GID" => "0",
      "_BOOT_ID" => "4737ffc504774b3ba67020bc947f1bc0",
      "_MACHINE_ID" => "bb9d0a52a41243829ecd729b40ac0bce",
      "_HOSTNAME" => "arch",
      "PRIORITY" => "5",
      "_TRANSPORT" => "syslog",
      "SYSLOG_FACILITY" => "10",
      "SYSLOG_IDENTIFIER" => "login",
      "_PID" => "141",
      "_COMM" => "login",
      "_EXE" => "/bin/login",
      "_AUDIT_SESSION" => "1",
      "_AUDIT_LOGINUID" => "0",
      "MESSAGE" => "ROOT LOGIN ON tty1",
      "_CMDLINE" => "login -- root      ",
      "_SYSTEMD_CGROUP" => "/user/root/1",
      "_SYSTEMD_SESSION" => "1",
      "_SYSTEMD_OWNER_UID" => "0",
      "_SOURCE_REALTIME_TIMESTAMP" => "1364519243563178",
    ]]
    d.run(expect_emits: 1)
    assert_equal(expected, d.events)
  end

end
