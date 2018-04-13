# systemd plugin for [Fluentd](http://github.com/fluent/fluentd)

[![Build Status](https://travis-ci.org/reevoo/fluent-plugin-systemd.svg?branch=master)](https://travis-ci.org/reevoo/fluent-plugin-systemd) [![Code Climate GPA](https://codeclimate.com/github/reevoo/fluent-plugin-systemd/badges/gpa.svg)](https://codeclimate.com/github/reevoo/fluent-plugin-systemd) [![Gem Version](https://badge.fury.io/rb/fluent-plugin-systemd.svg)](https://rubygems.org/gems/fluent-plugin-systemd)

## Overview

**systemd** input plugin reads logs from the systemd journal  
**systemd** filter plugin allows for basic manipulation of systemd journal entries

## Support

[![Fluentd Slack](http://slack.fluentd.org/badge.svg)](http://slack.fluentd.org/)

Join the #plugin-systemd channel on the [Fluentd Slack](http://slack.fluentd.org/)


## Requirements

|fluent-plugin-systemd|fluentd|td-agent|ruby|
|----|----|----|----|
| > 0.1.0 | >= 0.14.11, < 2 | 3 | >= 2.1 |
| 0.0.x | ~> 0.12.0       | 2 | >= 1.9  |

* The 0.x.x series is developed from this branch (master)
* The 0.0.x series (compatible with fluentd v0.12, and td-agent 2) is developed on the [0.0.x branch](https://github.com/reevoo/fluent-plugin-systemd/tree/0.0.x)

## Installation

Simply use RubyGems:

    gem install fluent-plugin-systemd -v 0.3.1

or

    td-agent-gem install fluent-plugin-systemd -v 0.3.1

## Input Plugin Configuration

    <source>
      @type systemd
      tag kube-proxy
      path /var/log/journal
      matches [{ "_SYSTEMD_UNIT": "kube-proxy.service" }]
      read_from_head true
      <storage>
        @type local
        persistent false
        path kube-proxy.pos
      </storage>
      <entry>
        field_map {"MESSAGE": "log", "_PID": ["process", "pid"], "_CMDLINE": "process", "_COMM": "cmd"}
        fields_strip_underscores true
        fields_lowercase true
      </entry>
    </source>

    <match kube-proxy>
      @type stdout
    </match>

**`path`**

Path to the systemd journal, defaults to `/var/log/journal`

**`filters`**

_This parameter name is deprecated and will be replaced with `matches` in a
future release._

Expects an array of hashes defining desired matches to apply to all log
messages. When this property is not specified, this plugin will default to
passing all logs.

See [matching details](docs/Matching-Details.md) for a more exhaustive
description of this property and how to use it (replacing references to
matches/matching with filters/filtering).

**`matches`**

Expects an array of hashes defining desired matches to apply to all log
messages. When this property is not specified, this plugin will default to
passing all logs.

See [matching details](docs/Matching-Details.md) for a more exhaustive
description of this property and how to use it.

**`pos_file`**

_This parameter is deprecated and will be removed in favour of storage in v1.0._


Path to pos file, stores the journald cursor. File is created if does not exist.

**`storage`**

Configuration for a [storage plugin](http://docs.fluentd.org/v0.14/articles/storage-plugin-overview) used to store the journald cursor.

_Upgrading from `pos_file`_

If `pos_file` is specified in addition to a storage plugin with persistent set to true, the cursor will be
copied from the `pos_file` on startup, and the old `pos_file` removed.

**`read_from_head`**

If true reads all available journal from head, otherwise starts reading from tail,
 ignored if pos file exists (and is valid). Defaults to false.

**`strip_underscores`**

_This parameter is deprecated and will be removed in favour of entry in v1.0._

If true strips underscores from the beginning of systemd field names.
May be useful if outputting to kibana, as underscore prefixed fields are unindexed there.

**`entry`**

Optional configuration for an embeded systemd entry filter. See the  [Filter Plugin Configuration](#filter-plugin-configuration) for config reference.

**`tag`**

_Required_

A tag that will be added to events generated by this input.

### Example

For an example of a full working setup including the plugin, [take a look at](https://github.com/assemblyline/fluentd)

## Filter Plugin Configuration

    <filter kube-proxy>
      @type systemd_entry
      field_map {"MESSAGE": "log", "_PID": ["process", "pid"], "_CMDLINE": "process", "_COMM": "cmd"}
      field_map_strict false
      fields_lowercase true
      fields_strip_underscores true
    </filter>

**`field_map`**

Object / hash defining a mapping of source fields to destination fields. Destination fields may be existing or new user-defined fields. If multiple source fields are mapped to the same destination field, the contents of the fields will be appended to the destination field in the order defined in the mapping. A field map declaration takes the form of:

    {
      "<src_field1>": "<dst_field1>",
      "<src_field2>": ["<dst_field1>", "<dst_field2>"],
      ...
    }
Defaults to an empty map.

**`field_map_strict`**

If true, only destination fields from `field_map` are included in the result. Defaults to false.

**`fields_lowercase`**

If true, lowercase all non-mapped fields. Defaults to false.

**`fields_strip_underscores`**

If true, strip leading underscores from all non-mapped fields. Defaults to false.

### Example

Given a systemd journal source entry:
```
{
  "_MACHINE_ID": "bb9d0a52a41243829ecd729b40ac0bce"
  "_HOSTNAME": "arch"
  "MESSAGE": "this is a log message",
  "_PID": "123"
  "_CMDLINE": "login -- root"
  "_COMM": "login"
}
```
The resulting entry using the above sample configuration:
```
{
  "machine_id": "bb9d0a52a41243829ecd729b40ac0bce"
  "hostname": "arch",
  "msg": "this is a log message",
  "pid": "123"
  "cmd": "login"
  "process": "123 login -- root"
}
```

## Common Issues

> ### When I look at fluentd logs, everything looks fine but no journal logs are read

This is commonly caused when the user running fluentd does not have enough permisions
to read the systemd journal.

Acording to the [systemd documentation](https://www.freedesktop.org/software/systemd/man/systemd-journald.service.html):
> Journal files are, by default, owned and readable by the "systemd-journal" system group but are not writable. Adding a user to this group thus enables her/him to read the journal files.


## Dependencies

This plugin depends on libsystemd

## Running the tests

To run the tests with docker on several distros simply run `rake`

For systems with systemd installed you can run the tests against your installed libsystemd with `rake test`

## Licence

[MIT](LICENCE)

## Contributions

Issues and pull requests are very welcome.

If you want to make a contribution but need some help or advice feel free to message me @errm on the [Fluentd Slack](http://slack.fluentd.org/), or send me an email edward-robinson@cookpad.com

We have adopted the [Contributor Covenant](CODE_OF_CONDUCT.md) and thus expect anyone interacting with contributors, maintainers and users of this project to abide by it.

## Maintainer

* [Ed Robinson](https://github.com/errm)

## Contributors

Many thanks to our fantastic contributors

* [Hiroshi Hatake](https://github.com/cosmo0920)
* [Erik Maciejewski](https://github.com/emacski)
* [Masahiro Nakagawa](https://github.com/repeatedly)
* [Richard Megginson](https://github.com/richm)
* [Mike Kaplinskiy](https://github.com/mikekap)
* [neko-neko](https://github.com/neko-neko)
* [Sadayuki Furuhashi](https://github.com/frsyuki)
* [Jesus Rafael Carrillo](https://github.com/jescarri)
* [John Thomas Wile II](https://github.com/jtwile2)
* [Kazuhiro Suzuki](https://github.com/ksauzz)
