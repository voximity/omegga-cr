# omegga-cr

This is an RPC interface for [Omegga](https://github.com/brickadia-community/omegga).

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     omegga-cr:
       github: voximity/omegga-cr
   ```

2. Run `shards install`

### Extra steps

To make your plugin usable, add the file `omegga_plugin` and make sure to include it in your repository:

```sh
#!/bin/bash
cd plugins/name-of-plugin-repo
shards build -q && ./bin/name-of-shard
```

Be sure to change `name-of-plugin-repo` to the name of your plugin's repository and `name-of-shard` to the name you gave it in your `shard.yml`.

## Usage

An example plugin using omegga-cr:

```cr
require "omegga-cr"
include Omegga

omegga = RPCClient.new

omegga.on_init do
  omegga.log "Hello, this is omegga-cr!"

  next RegisteredCommands.new ["test"] # instantiate a `RegisteredCommands` with an `Array(String)` representing the slash commands you add
end

omegga.on_command "test" do |user| # runs when a user types `/test` in chat
  omegga.whisper user, "Hello! You ran the test command."
end

omegga.on_chat_command "pos" do |user, args| # runs when a user types `!pos` (or more) in chat
  target = args[0]? || user
  pos = omegga.get_player_position target
  omegga.whisper user, "That player is at position #{pos}."
end

omegga.on_chat_command "brickcount" do |user| # runs when a user types `!brickcount` in chat
  omegga.broadcast "There are #{omegga.get_save_data.brick_count} bricks. #{user}." # Omegga::BRS::Save is a complete mirror of save properties from `brs-js`.
end

omegga.start
```

An extra note: you **must not** use `puts` unless you wish to interface the RPC server. Instead, use `RPCClient#log` to write text to the console.

## Contributing

1. Fork it (<https://github.com/voximity/omegga-cr/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [voximity](https://github.com/voximity) - creator and maintainer
- [Meshiest](https://github.com/Meshiest) - Omegga
