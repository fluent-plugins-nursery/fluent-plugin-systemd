# frozen_string_literal: true

require_relative '../helper'
require_relative './systemd/test_entry_mutator'
require 'fluent/test/driver/filter'
require 'fluent/plugin/filter_systemd_entry'

class SystemdEntryFilterTest < Test::Unit::TestCase
  include Fluent::Test::Helpers
  # filter test data in the form:
  # { test_name: [filter_config, expected_entry], ... }
  @tests = {
    no_transform: [
      '',
      EntryTestData::EXPECTED[:no_transform]
    ],
    fields_strip_underscores: [
      %(
        fields_strip_underscores true
      ),
      EntryTestData::EXPECTED[:fields_strip_underscores]
    ],
    fields_lowercase: [
      %(
        fields_lowercase true
      ),
      EntryTestData::EXPECTED[:fields_lowercase]
    ],
    field_map: [
      %(
        field_map #{EntryTestData::FIELD_MAP_JSON}
      ),
      EntryTestData::EXPECTED[:field_map]
    ],
    field_map_strict: [
      %(
        field_map #{EntryTestData::FIELD_MAP_JSON}
        field_map_strict true
      ),
      EntryTestData::EXPECTED[:field_map_strict]
    ]
  }

  def setup
    Fluent::Test.setup
  end

  def create_driver(config)
    Fluent::Test::Driver::Filter.new(Fluent::Plugin::SystemdEntryFilter).configure(config)
  end

  data(@tests)
  def test_filter(data)
    conf, expect = data
    d = create_driver(conf)
    d.run do
      d.feed('test', 1_364_519_243, EntryTestData::ENTRY.to_h)
    end
    expected = [[
      1_364_519_243,
      expect
    ]]
    assert_equal(expected, d.filtered)
  end
end
