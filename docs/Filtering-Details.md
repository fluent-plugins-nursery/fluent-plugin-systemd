# Filtering Details

## Overview

This application takes an array of hashes passed to the `filters` parameter
within a `systemd` typed source definition in your `fluent.conf` configuration
file and then parses them into a format understood by `systemd`'s `journald`
API. The basis behind what `journald`'s API expects can be found documented in
the `journalctl` [man
page](https://www.freedesktop.org/software/systemd/man/journalctl.html).

## Usage Information

In order to utilize this plugin's filtering capabilities, you will need to
understand how this plugin transforms the passed array of hashes into a format
that is understood by `journald`.

The best way to describe this process is probably by example. The following
sub-sections lists out various scenarios that you might wish to perform with
this plugin's filtering mechanism and describes both how to configure them,
while also mapping them to examples from the `journalctl` [man
page](https://www.freedesktop.org/software/systemd/man/journalctl.html).

### No Filters

You can leave the `filters` property out altogether, or include a `filters`
property with an empty array (as shown below) to specify that no filtering
should occur.

    filters []

Which matches this part of the `journalctl` man page:

> Without arguments, all collected logs are shown unfiltered:
>
> `journalctl`

### Single Filter

You can pass a single hash map to the `filters` array with a single key/value
pair specified to filter out all log entries that do not match the given
field/value combination.

For example:

    filters [{"_SYSTEMD_UNIT": "avahi-daemon.service"}]

Which coincides with this part of the the `journalctl` man page:

> With one match specified, all entries with a field matching the expression are
> shown:
> 
> `journalctl _SYSTEMD_UNIT=avahi-daemon.service`

### Multi-Field Filters

You can pass a single hash map to the `filters` array with multiple key/value
pairs to filter out all log entries that do not match the combination of all of
the specified key/value combinations.

The passed key/value pairs are treated as a logical `AND`, such that all of the
pairs must be true in order to allow further processing of the current log
entry.

For Example:

    filters [{"_SYSTEMD_UNIT": "avahi-daemon.service", "_PID": 28097}]

Which coincides with this part of the the `journalctl` man page:

> If two different fields are matched, only entries matching both expressions at
> the same time are shown:
> 
> `journalctl _SYSTEMD_UNIT=avahi-daemon.service _PID=28097`

You can also perform a logical `OR` by splitting key/value pairs across multiple
hashes passed to the `filters` array like so:

    filters [{"_SYSTEMD_UNIT": "avahi-daemon.service"}, {"_PID": 28097}]

You can combine both `AND` and `OR` combinations together; using a single hash
map to define conditions that `AND` together and using multiple hash maps to
define conditions that `OR` together like so:

    filters [{"_SYSTEMD_UNIT": "avahi-daemon.service", "_PID": 28097}, {"_SYSTEMD_UNIT": "dbus.service"}]

This can be expressed in psuedo-code like so:

    IF (_SYSTEMD_UNIT=avahi-daemon.service AND _PID=28097) OR _SYSTEMD_UNIT=dbus.service
    THEN PASS
    ELSE DENY

Which coincides with this part of the `journalctl` man page:

> If the separator "+" is used, two expressions may be combined in a logical OR.
> The following will show all messages from the Avahi service process with the
> PID 28097 plus all messages from the D-Bus service (from any of its
> processes):
> 
> `journalctl _SYSTEMD_UNIT=avahi-daemon.service _PID=28097 + _SYSTEMD_UNIT=dbus.service`

### Multi-Value Filters

Fields with arrays as values are treated as a logical `OR` statement.

For example:

    filters [{"_SYSTEMD_UNIT": ["avahi-daemon.service", "dbus.service"]}]

Which coincides with this part of the `journalctl` man page:

> If two matches refer to the same field, all entries matching either expression
> are shown:
> 
> `journalctl _SYSTEMD_UNIT=avahi-daemon.service _SYSTEMD_UNIT=dbus.service`

The above example can be equivalently broken into 2 separate hashes. This is
particularly helpful when you want to create aggregate logic

For example:

    filters [{"_SYSTEMD_UNIT": "avahi-daemon.service", "_PID": 28097}, {"_SYSTEMD_UNIT": "dbus.service"}]

This can be expressed in psuedo-code like so:

    IF (_SYSTEMD_UNIT=avahi-daemon.service AND _PID=28097) OR _SYSTEMD_UNIT=dbus.service
    THEN PASS
    ELSE DENY

Which coincides with this part of the `journalctl` man page:

> If the separator "+" is used, two expressions may be combined in a logical OR.
> The following will show all messages from the Avahi service process with the
> PID 28097 plus all messages from the D-Bus service (from any of its
> processes):
>
> `journalctl _SYSTEMD_UNIT=avahi-daemon.service _PID=28097 + _SYSTEMD_UNIT=dbus.service`

### Wildcard Filters

`systemd`/`journald` does not presently support wild-card filtering, so neither
can this plugin.
