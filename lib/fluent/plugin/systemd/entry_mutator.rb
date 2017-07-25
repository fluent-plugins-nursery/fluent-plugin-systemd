# frozen_string_literal: true
require "fluent/config/error"

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
        :fields_strip_underscores,
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
          fld = fld.gsub(/\A_+/, "") if @opts.fields_strip_underscores
          fld = fld.downcase if @opts.fields_lowercase
          # account for mapping (appending) to an existing systemd field
          mapped[fld] = mapped.key?(fld) ? [val, mapped[fld]].join(" ") : val
        end
        mapped
      end

      private

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
        unless validate_strings_or_empty(opts[:field_map].keys)
          err = "`field_map` keys must be strings"
        end
        unless validate_strings_or_empty(opts[:field_map].values, true)
          err = "`field_map` values must be strings or array of strings"
        end
        %i[field_map_strict fields_strip_underscores fields_lowercase].each do |opt|
          err = "`#{opt}` must be boolean" unless [true, false].include?(opts[opt])
        end
        fail Fluent::ConfigError, err unless err.nil?
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
      # the mutator uses for the actual mapping. The resulting structure for
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
