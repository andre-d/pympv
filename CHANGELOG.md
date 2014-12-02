pympv
=====

## 0.2.1

- Fix possible failures setting property to a map
- Fix possible failures with every single string


## 0.2

- EOFReasons.restart removed to reflect client.h enum
- Bump to require libmpv 1.9
- Switch mpv.command() to use mpv_command_node, non-async will now return comamnd response data.
  This should make no difference to users, but now accepts various forms of data instead of just strings.
- Add try_get_property_async and try_get_property
- Add support for EndOfFileReached.error and EOFReasons.error
- Add support for LogMessage.log_level and LogLevels
- Fix Errors values being positive rather than negative (And totally wrong as a result)
- Add a few new Errors values
- Add support for setting properties, options, and commands to lists and maps
