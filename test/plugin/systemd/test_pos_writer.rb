require_relative "../../helper"
require "tempfile"
require "fluent/plugin/systemd/pos_writer"

class SystemdInputTest < Test::Unit::TestCase
  def test_reading_the_cursor_when_file_exists
    pos_file = Tempfile.new("foo.pos")
    pos_file.write("cursor_value")
    pos_file.close
    pos_writer = Fluent::Plugin::SystemdInput::PosWriter.new(pos_file.path)
    assert_equal pos_writer.cursor, "cursor_value"
    pos_file.unlink
  end

  def test_reading_the_cursor_when_file_does_not_exist_yet
    dir = Dir.mktmpdir("posdir")
    path = "#{dir}/foo.pos"
    pos_writer = Fluent::Plugin::SystemdInput::PosWriter.new(path)
    assert_equal pos_writer.cursor, nil
    FileUtils.rm_rf dir
  end

  def test_writing_the_cursor_when_file_does_not_exist_yet
    dir = Dir.mktmpdir("posdir")
    path = "#{dir}/foo.pos"
    pos_writer = Fluent::Plugin::SystemdInput::PosWriter.new(path)
    pos_writer.start
    pos_writer.update("this is the cursor")
    assert_equal pos_writer.cursor, "this is the cursor"
    sleep 1
    assert_equal File.read(path), "this is the cursor"
    FileUtils.rm_rf dir
  end

  def test_writing_the_cursor_when_the_writer_is_shutdown
    dir = Dir.mktmpdir("posdir")
    path = "#{dir}/foo.pos"
    pos_writer = Fluent::Plugin::SystemdInput::PosWriter.new(path)
    pos_writer.start
    pos_writer.update("this is the cursor")
    pos_writer.shutdown
    assert_equal File.read(path), "this is the cursor"
    FileUtils.rm_rf dir
  end

  def test_writing_the_cursor_when_the_file_exists
    pos_file = Tempfile.new("foo.pos")
    pos_file.write("cursor_value")
    pos_file.close
    pos_writer = Fluent::Plugin::SystemdInput::PosWriter.new(pos_file.path)
    assert_equal pos_writer.cursor, "cursor_value"
    pos_writer.start
    pos_writer.update("this is the cursor")
    sleep 1
    assert_equal File.read(pos_file.path), "this is the cursor"
    pos_file.unlink
  end

  def test_writing_and_then_reading_the_pos_roundtrip
    dir = Dir.mktmpdir("posdir")
    path = "#{dir}/foo.pos"
    pos_writer = Fluent::Plugin::SystemdInput::PosWriter.new(path)
    pos_writer.start
    pos_writer.update("this is the cursor")
    pos_writer.shutdown
    pos_writer = Fluent::Plugin::SystemdInput::PosWriter.new(path)
    assert_equal pos_writer.cursor, "this is the cursor"
    FileUtils.rm_rf dir
  end
end
