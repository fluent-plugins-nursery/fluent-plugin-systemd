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

require 'fluent/plugin/filter'
require 'fluent/plugin/systemd/entry_mutator'

module Fluent
  module Plugin
    # Fluentd systemd/journal filter plugin
    class SystemdEntryFilter < Filter
      Fluent::Plugin.register_filter('systemd_entry', self)

      config_param :field_map, :hash, default: {}
      config_param :field_map_strict, :bool, default: false
      config_param :fields_strip_underscores, :bool, default: false
      config_param :fields_lowercase, :bool, default: false

      def configure(conf)
        super
        @mutator = SystemdEntryMutator.new(**@config_root_section.to_h)
        @mutator.warnings.each { |warning| log.warn(warning) }
      end

      def filter(_tag, _time, entry)
        @mutator.run(entry)
      end
    end
  end
end
