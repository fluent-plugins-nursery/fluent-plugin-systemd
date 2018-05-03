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

require 'fluent/config/error'

module Fluent
  module Plugin
    # A simple stand-alone configurable mutator for systemd journal entries.
    #
    # Note regarding field mapping:
    # The input `field_map` option is meant to have a structure that is
    # intuative or logical for humans when declaring a field map.
    # {
    #   "<source_field1>" => "<new_field1>",
    #   "<source_field2>" => ["<new_field1>", "<new_field2>"]
    # }
    # Internally the inverse of the human-friendly field_map is
    # computed (and cached) upon object creation and used as a "mapped model"
    # {
    #   "<new_field1>" => ["<source_field1>", "<source_field2>"],
    #   "<new_field2>" => ["<source_field2>"]
    # }
    class SystemdEntryMutator
      Options = Struct.new(
        :field_map,
        :field_map_strict,
        :fields_lowercase,
        :fields_strip_underscores
      )

      def self.default_opts
        Options.new({}, false, false, false)
      end

      # Constructor keyword options (all other kwargs are ignored):
      # field_map - hash describing the desired field mapping in the form:
      #             {"<source_field>" => "<new_field>", ...}
      #             where `new_field` is a string or array of strings
      # field_map_strict - boolean if true will only include new fields
      #                    defined in `field_map`
      # fields_strip_underscores - boolean if true will strip all leading
      #                            underscores from non-mapped fields
      # fields_lowercase - boolean if true lowercase all non-mapped fields
      #
      # raises `Fluent::ConfigError` for invalid options
      def initialize(**options)
        @opts = options_from_hash(options)
        validate_options(@opts)
        @map = invert_field_map(@opts.field_map)
        @map_src_fields = @opts.field_map.keys
        @no_transform = @opts == self.class.default_opts
      end

      # Expose config state as read-only instance properties of the mutator.
      def method_missing(sym, *args)
        return @opts[sym] if @opts.members.include?(sym)
        super
      end

      def respond_to_missing?(sym, include_private = false)
        @opts.members.include?(sym) || super
      end

      # The main run method that performs all configured mutations, if any,
      # against a single journal entry. Returns the mutated entry hash.
      # entry - hash or `Systemd::Journal:Entry`
      def run(entry)
        return entry.to_h if @no_transform
        return map_fields(entry) if @opts.field_map_strict
        format_fields(entry, map_fields(entry))
      end

      # Run field mapping against a single journal entry. Returns the mutated
      # entry hash.
      # entry - hash or `Systemd::Journal:Entry`
      def map_fields(entry)
        @map.each_with_object({}) do |(cstm, sysds), mapped|
          vals = sysds.collect { |fld| entry[fld] }.compact
          next if vals.empty? # systemd field does not exist in source entry
          mapped[cstm] = join_if_needed(vals)
        end
      end

      # Run field formatting (mutations applied to all non-mapped fields)
      # against a single journal entry. Returns the mutated entry hash.
      # entry - hash or `Systemd::Journal:Entry`
      # mapped - Optional hash that represents a previously mapped entry to
      #          which the formatted fields will be added
      def format_fields(entry, mapped = nil)
        entry.each_with_object(mapped || {}) do |(fld, val), formatted_entry|
          # don't mess with explicitly mapped fields
          next if @map_src_fields.include?(fld)
          fld = format_field_name(fld)
          # account for mapping (appending) to an existing systemd field
          formatted_entry[fld] = join_if_needed([val, mapped[fld]])
        end
      end

      def warnings
        return [] unless field_map_strict && field_map.empty?
        '`field_map_strict` set to true with empty `field_map`, expect no fields'
      end

      private

      def join_if_needed(values)
        values.compact!
        return values.first if values.length == 1
        values.join(' ')
      end

      def format_field_name(name)
        name = name.gsub(/\A_+/, '') if @opts.fields_strip_underscores
        name = name.downcase if @opts.fields_lowercase
        name
      end

      # Returns a `SystemdEntryMutator::Options` struct derived from the
      # elements in the supplied hash merged with the option defaults
      def options_from_hash(opts)
        merged = self.class.default_opts
        merged.each_pair do |k, _|
          merged[k] = opts[k] if opts.key?(k)
        end
        merged
      end

      def validate_options(opts)
        validate_all_strings opts[:field_map].keys, '`field_map` keys must be strings'
        validate_all_strings opts[:field_map].values, '`field_map` values must be strings or an array of strings', true
        %i[field_map_strict fields_strip_underscores fields_lowercase].each do |opt|
          validate_boolean opts[opt], opt
        end
      end

      def validate_all_strings(arr, message, allow_nesting = false)
        valid = arr.all? do |value|
          value.is_a?(String) || allow_nesting && value.is_a?(Array) && value.all? { |key| key.is_a?(String) }
        end
        raise Fluent::ConfigError, message unless valid
      end

      def validate_boolean(value, name)
        raise Fluent::ConfigError, "`#{name}` must be boolean" unless [true, false].include?(value)
      end

      # Compute the inverse of a human friendly field map `field_map` which is what
      # the mutator uses for the actual mapping. The resulting structure for
      # the inverse field map hash is:
      # {"<new_field_name>" => ["<source_field_name>", ...], ...}
      def invert_field_map(field_map)
        invs = {}
        field_map.values.flatten.uniq.each do |cstm|
          sysds = field_map.select { |_, v| (v == cstm || v.include?(cstm)) }
          invs[cstm] = sysds.keys
        end
        invs
      end
    end
  end
end
