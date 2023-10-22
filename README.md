# DICT protocol

Crystal implementation of the DICT protocol
([RFC 2229](https://www.rfc-editor.org/rfc/rfc2229)).

## Installation

1. Add the dependency to your `shard.yml`:

```yaml
dependencies:
  dict-protocol:
    github: singond/dict-protocol
```

2. Run `shards install`

## Usage

```crystal
require "dict-protocol"
```

## Contributing

1. Fork it (<https://github.com/singond/dict-protocol/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

### Running tests
The tests use the `Log` class to log messages.
To see the messages, set the `LOG_LEVEL` environment variable:
```
LOG_LEVEL=info crystal spec
```

## Contributors

- [Jan Singon Slany](https://github.com/singond) - creator and maintainer
