# frozen_string_literal: true
require_relative "../../helper"
require "tempfile"
require "fluent/plugin/systemd/pos_writer"

class SystemdInputTest < Test::Unit::TestCase # rubocop:disable Metrics/ClassLength
  class FakeStorage
    def initialize(options)
      @persistent = options[:persistent]
      @store = {}
    end

    attr_reader :persistent

    def put(key, value)
      @store[key] = value
    end

    def get(key)
      @store[key]
    end
  end

  def storage(options = {})
    FakeStorage.new(options)
  end

  def test_reading_the_cursor_when_file_exists
    pos_file = Tempfile.new("foo.pos")
    pos_file.write("cursor_value")
    pos_file.close
    pos_writer = Fluent::Plugin::SystemdInput::PosWriter.new(pos_file.path, storage)
    assert_equal pos_writer.get(:journal), "cursor_value"
    pos_file.unlink
  end

  def test_reading_the_cursor_when_file_does_not_exist_yet
    dir = Dir.mktmpdir("posdir")
    path = "#{dir}/foo.pos"
    pos_writer = Fluent::Plugin::SystemdInput::PosWriter.new(path, storage)
    assert_equal pos_writer.get(:journal), nil
    FileUtils.rm_rf dir
  end

  def test_reading_the_cusor_when_the_path_is_nil
    pos_writer = Fluent::Plugin::SystemdInput::PosWriter.new(nil, storage)
    assert_equal pos_writer.get(:journal), nil
    pos_writer.put(:journal, "a_cursor")
    assert_equal pos_writer.get(:journal), "a_cursor"
  end

  def test_writing_the_cursor_when_file_does_not_exist_yet
    dir = Dir.mktmpdir("posdir")
    path = "#{dir}/foo.pos"
    pos_writer = Fluent::Plugin::SystemdInput::PosWriter.new(path, storage)
    pos_writer.start
    pos_writer.put(:journal, "this is the cursor")
    assert_equal pos_writer.get(:journal), "this is the cursor"
    sleep 1
    assert_equal File.read(path), "this is the cursor"
    FileUtils.rm_rf dir
  end

  def test_file_permission_when_file_does_not_exist_yet
    dir = Dir.mktmpdir("posdir")
    path = "#{dir}/foo.pos"
    pos_writer = Fluent::Plugin::SystemdInput::PosWriter.new(path, storage)
    pos_writer.start
    pos_writer.put(:journal, "this is the cursor")
    sleep 1
    assert_equal format("%o", File::Stat.new(path).mode)[-4, 4], "0644"
    FileUtils.rm_rf dir
  end

  def test_writing_the_cursor_when_the_writer_is_shutdown
    dir = Dir.mktmpdir("posdir")
    path = "#{dir}/foo.pos"
    pos_writer = Fluent::Plugin::SystemdInput::PosWriter.new(path, storage)
    pos_writer.start
    pos_writer.put(:journal, "this is the cursor")
    pos_writer.shutdown
    assert_equal File.read(path), "this is the cursor"
    FileUtils.rm_rf dir
  end

  def test_writing_the_cursor_when_the_file_exists # rubocop:disable Metrics/AbcSize
    pos_file = Tempfile.new("foo.pos")
    pos_file.write("cursor_value")
    pos_file.close
    pos_writer = Fluent::Plugin::SystemdInput::PosWriter.new(pos_file.path, storage)
    assert_equal pos_writer.get(:journal), "cursor_value"
    pos_writer.start
    pos_writer.put(:journal, "this is the cursor")
    sleep 1
    assert_equal File.read(pos_file.path), "this is the cursor"
    pos_file.unlink
  end

  def test_writing_and_then_reading_the_pos_roundtrip
    dir = Dir.mktmpdir("posdir")
    path = "#{dir}/foo.pos"
    pos_writer = Fluent::Plugin::SystemdInput::PosWriter.new(path, storage)
    pos_writer.start
    pos_writer.put(:journal, "this is the cursor")
    pos_writer.shutdown
    pos_writer = Fluent::Plugin::SystemdInput::PosWriter.new(path, storage)
    assert_equal pos_writer.get(:journal), "this is the cursor"
    FileUtils.rm_rf dir
  end

  def test_upgrading_from_pos_writer_to_storage # rubocop:disable Metrics/AbcSize
    store = storage(persistent: true)
    pos_file = Tempfile.new("foo.pos")
    pos_file.write("cursor_value")
    pos_file.close
    pos_writer = Fluent::Plugin::SystemdInput::PosWriter.new(pos_file.path, store)

    # It removes the old file
    assert !File.exist?(pos_file.path)

    # it copies the value to the store
    assert_equal store.get(:journal), "cursor_value"

    # it uses the store
    pos_writer.put(:journal, "new_value")
    assert_equal store.get(:journal), "new_value"

    # start and shutdown should be noops
    pos_writer.put(:journal, "another_value")
    assert_nil pos_writer.start
    assert_nil pos_writer.shutdown
    assert_equal pos_writer.get(:journal), "another_value"
    assert_equal store.get(:journal), "another_value"
  end

  def test_when_the_old_pos_writer_file_does_not_exist
    store = storage(persistent: true)
    pos_writer = Fluent::Plugin::SystemdInput::PosWriter.new("not_a_real_path_to_a_file", store)
    assert_nil store.get(:journal)

    # it works
    pos_writer.put(:journal, "new_value")
    assert_equal store.get(:journal), "new_value"
    assert_equal pos_writer.get(:journal), "new_value"
  end

  def test_when_no_pos_file_path_given
    # uses storage even if not persistent
    store = storage(persistent: false)
    pos_writer = Fluent::Plugin::SystemdInput::PosWriter.new(nil, store)

    pos_writer.put(:journal, "new_value")
    assert_equal store.get(:journal), "new_value"
    assert_equal pos_writer.get(:journal), "new_value"
  end
end
