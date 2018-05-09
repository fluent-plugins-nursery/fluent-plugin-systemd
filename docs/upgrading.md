# Upgrading

## To Version 1.0

Version 1.0 removes a number of configuration options that had been deprecated by previous versions of the plugin. This was done to reduce the size of the code base and make maintenance simpler.

If you have been paying attention to (and fixing) the deprecation warnings introduced by previous versions of the plugin then there is nothing for you to do. If you have not already done so it is recommended to first upgrade to version `0.3.1` and fix any warnings before trying version `1.0.0` or above.

Version 1.0 of fluent-plugin-systemd only supports fluentd 0.14.11 and above (including fluentd 1.0+), if you are using tdagent you need to be using version 3 or above.

### `pos_file`

Previous versions of the plugin used the `pos_file` config value to specify a file that the position or cursor from the systemd journal would be written to. This was replaced by a generic fluentd storage block that allows much more flexibility in how the cursor is persisted. Take a look at the [fluentd documentation](https://docs.fluentd.org/v1.0/articles/storage-section) to find out more about this.

Before you upgrade to 1.0 you should migrate `pos_file` to a storage block.

```
pos_file /var/log/journald.pos
```

could be rewritten as

```
<storage>
  @type local
  persistent true
  path /var/log/journald_pos.json
</storage>
```

If you want to update this configuration without skipping any entries if you supply the `pos_file` and a storage block at the same time version `0.3.1` will copy the cursor from the path given in `pos_file` to the given storage.

### `strip_underscores`

The legacy `strip_underscores` method is removed in version `1.0.0` and above. The same functionality can be achieved by setting the `fields_strip_underscores` on an entry block. The entry block allows many more options for mutating journal entries.

```
strip_underscores true
```

should be rewritten as

```
<entry>
  fields_strip_underscores true
</entry>
```

### `filters`

In version 1.0.0 the `filters` parameter was renamed as `matches` in order to more closely align the plugin with the names used in the systemd documentation. `filters` is deprecated and will be removed in a future version. Other than renaming the parameter no changes have been made to it's structure or operation.

