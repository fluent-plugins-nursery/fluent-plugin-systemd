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
