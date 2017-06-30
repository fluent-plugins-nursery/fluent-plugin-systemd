# frozen_string_literal: true
module Fluent
  module Plugin
    module Systemd
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
      class EntryMutator
        OptionError = Class.new(StandardError)

        DEFAULT_OPTIONS = {
          field_map: {},
          field_map_strict: false,
          fields_strip_underscores: false,
          fields_lowercase: false,
        }.freeze

        # Constructor keyword options (all other kwargs are ignored):
        # field_map - A hash describing the desired field mapping in the form:
        #             {"<source_field>" => "<new_field>", ...}
        #             where `new_field` is a string or array of strings
        # field_map_strict - A boolean if true will only include new fields
        #                    defined in `field_map`
        # fields_strip_underscores - A boolean if true will strip all leading
        #                            underscores from non-mapped fields
        # fields_lowercase - A boolean if true lowercase all non-mapped fields
        def initialize(**options)
          options = DEFAULT_OPTIONS.merge(options)
          validate_options(options)
          @map = invert_field_map(options[:field_map])
          @map_src_fields = options[:field_map].keys
          @map_strict = options[:field_map_strict]
          @lowercase = options[:fields_lowercase]
          @strip_underscores = options[:fields_strip_underscores]
        end

        # The main run method that performs all configured mutations against a
        # single journal entry. Returns the mutated entry hash.
        # entry - hash or `Systemd::Journal:Entry`
        def run(entry)
          return map_fields(entry) if @map_strict
          format_fields(entry, map_fields(entry))
        end

        # Run field mapping against a single journal entry. Returns the mutated
        # entry hash.
        # entry - hash or `Systemd::Journal:Entry`
        def map_fields(entry)
          mapped = {}
          @map.each do |cstm, sysds|
            vals = sysds.collect { |fld| entry[fld] }.compact
            next if vals.empty? # systemd field does not exist in source entry
            mapped[cstm] = vals.length == 1 ? vals[0] : vals.join(" ")
          end
          mapped
        end

        # Run field formatting (mutations applied to all non-mapped fields)
        # against a single journal entry. Returns the mutated entry hash.
        # entry - hash or `Systemd::Journal:Entry`
        # mapped - Optional hash that represents a previously mapped entry to
        #          which the formatted fields will be added
        def format_fields(entry, mapped = nil)
          mapped ||= {}
          entry.each do |fld, val|
            # don't mess with explicitly mapped fields
            next if @map_src_fields.include?(fld)
            fld = fld.gsub(/\A_+/, "") if @strip_underscores
            fld = fld.downcase if @lowercase
            # account for mapping (appending) to an existing systemd field
            mapped[fld] = mapped.key?(fld) ? [val, mapped[fld]].join(" ") : val
          end
          mapped
        end

        private

        def validate_options(options)
          unless validate_strings_or_empty(options[:field_map].keys)
            err = "`field_map` keys must be strings"
          end
          unless validate_strings_or_empty(options[:field_map].values, true)
            err = "`field_map` values must be strings or array of strings"
          end
          %i[field_map_strict fields_strip_underscores fields_lowercase].each do |opt|
            err = "`#{opt}` must of of type boolean" unless [true, false].include?(options[opt])
          end
          fail OptionError, err unless err.nil?
        end

        # Validates that values in array `arr` are strings. If `nested` is true
        # also allow and validate that `arr` values can be an array of strings
        def validate_strings_or_empty(arr, nested = false)
          return true if arr.empty?
          arr.each do |v|
            return true if v.is_a?(String)
            if v.is_a?(Array) && nested
              v.each { |nstd| return false unless nstd.is_a?(String) }
            end
          end
          false
        end

        # Compute the inverse of a human friendly field map `fm` which is what
        # the mutator uses for the actual mapping. The resulting sturcture for
        # the inverse field map hash is:
        # {"<new_field_name>" => ["<source_field_name>", ...], ...}
        def invert_field_map(fm)
          invs = {}
          fm.values.flatten.uniq.each do |cstm|
            sysds = fm.select { |_, v| (v == cstm || v.include?(cstm)) }
            invs[cstm] = sysds.keys
          end
          invs
        end
      end
    end
  end
end
