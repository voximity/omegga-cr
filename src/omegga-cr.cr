require "json"
require "uuid"
require "uuid/json"

require "./omegga-cr/brs"
require "./omegga-cr/log_wrangler"
require "./omegga-cr/player"
require "./omegga-cr/rpc"
require "./omegga-cr/vector"

class String
  def br_colorize(color : String)
    "<color=\"#{color}\">#{self}</>"
  end

  def br_bold
    "<b>#{self}</>"
  end

  def br_colorize(color : Symbol)
    c = "fff"
    case color
    when :red
      c = "f00"
    when :green
      c = "0f0"
    when :blue
      c = "00f"
    when :yellow
      c = "ff0"
    when :cyan
      c = "0ff"
    when :magenta
      c = "f0f"
    when :white
      c = "fff"
    when :black
      c = "000"
    when :gray
      c = "aaa"
    end
    br_colorize(c)
  end
end

module Omegga
  extend self

  class RegisteredCommands
    include JSON::Serializable

    @[JSON::Field(key: "registeredCommands")]
    property commands : Array(String)

    def initialize(@commands)
    end

    def initialize
      @commands = [] of String
    end
  end

  class RPCClient
    
    # :nodoc:
    macro event(name, *params, returns = Nil)
      {% listener_name = name.id.split("_").map(&.capitalize).join("").id %}
      def on_{{name}}(&block : {{*params}} -> {{returns}}) : Event{{listener_name}}Listener
        listener = Event{{listener_name}}Listener.new(block)
        @{{name}}_listeners << listener
        listener        
      end
      {% if returns.stringify == "Nil" %}
      protected def fire_{{name}}(*args)
        @{{name}}_listeners.try &.each &.call(*args)
      end
      {% else %}
      protected def fire_{{name}}(*args) : {{returns}}
        @{{name}}_listeners[0].call(*args)
      end
      {% end %}
      # :nodoc
      struct Event{{listener_name}}Listener
        {% if params.size == 0 %}
          getter proc : Proc({{returns}})
        {% else %}
          getter proc : Proc({{*params}}, {{returns}})
        {% end %}
        def call(*args)
          @proc.call(*args)
        end
        def destroy
          @{{name}}_listeners.delete(self)
        end
        def initialize(@proc)
        end
      end
      @{{name}}_listeners : Array(Event{{listener_name}}Listener) = [] of Event{{listener_name}}Listener
    end

    # Send a notification to the server.
    protected def send(payload : RPC::Notification)
      STDOUT.puts payload.to_json
    end

    # Send a request to the server, expecting a response.
    protected def ask(method : String, params : T) : RPC::Response(JSON::Any) forall T
      id : Int32 = -1
      until !@channel_map.has_key?(id)
        id -= 1
      end

      payload = RPC::Request(T).new(method, params, id)

      @channel_map[id] = Channel(RPC::Response(JSON::Any)).new
      STDOUT.puts payload.to_json
      response = @channel_map[id].receive
      @channel_map.delete(id)
      
      response
    end

    # Send a request to the server, ignoring response. We only care about errors here.
    protected def invoke(method : String, params : T) forall T
      response = ask method, params
      raise RPC::RPCError.new(response.error.not_nil!) unless response.error.nil?
    end

    # Respond to a request from the server.
    protected def respond(payload : RPC::Response(T)) forall T
      STDOUT.puts payload.to_json
    end


    @channel_map : Hash(RPC::Id, Channel(RPC::Response(JSON::Any))) = {} of RPC::Id => Channel(RPC::Response(JSON::Any))



    ### EVENTS

    # Fired when the plugin initializes.
    event init, Hash(String, JSON::Any), returns: RegisteredCommands?

    # Fired when the plugin must stop.
    event stop

    # Fired when a player sends a message.
    event chat, String, String

    struct EventCommandListener
      getter proc : Proc(String, Array(String), Nil)
      getter command : String
      getter is_chat : Bool
      def call(*args)
        @proc.call(*args)
      end
      def destroy
        @command_listeners.delete(self)
      end
      def initialize(@proc, @command, @is_chat)
      end
    end

    @command_listeners = [] of EventCommandListener

    # Fired when a player runs a chat command (starting with !).
    def on_chat_command(command : String, &block : (String, Array(String)) ->)
      @command_listeners << EventCommandListener.new(block, command, true)
    end

    # Fired when a player runs a command (starting with /).
    def on_command(command : String, &block : (String, Array(String)) ->)
      @command_listeners << EventCommandListener.new(block, command, false)
    end

    protected def fire_command(command : String, is_chat : Bool, user : String, args : Array(String))
      @command_listeners.select { |l| l.command == command && l.is_chat == is_chat }.each &.call(user, args)
    end

    # Fired when a line is sent from the Brickadia server. Passed is the line in question.
    event line, String

    # Fired when the Brickadia server starts. Passed is the name of the map the server started with.
    event start, String

    # Fired when the Brickadia server detects the host. Passed is the name and ID of the host.
    event host, String, UUID
    
    # Fired when the Brickadia server detects the version.
    event version, String

    # Fired when the Brickadia server fails the auth check.
    event unauthorized

    # Fired when a player joins the server.
    event join, Player

    # Fired when a player leaves the server.
    event leave, Player


 
    ### METHODS

    macro rpc_log(type)
      def {{type}}(content : String)
        invoke {{type.stringify}}, content
      end
    end

    # Log to the Omegga output. This MUST be used over `puts` for logging information. `puts` will write to the RPC connection.
    rpc_log log

    # Write an error to the Omegga output.
    rpc_log error

    # Write an info message to the Omegga output.
    rpc_log info

    # Write a warning to the Omegga output.
    rpc_log warn

    # Write a message with a stack trace to the Omegga output.
    rpc_log trace

    # Get the value of an object by its key from the store. Response is a `JSON::Any`. Raises if no value is found.
    def store_get(key : String) : JSON::Any
      response = ask "store.get", key
      raise "No value in store" if response.result.nil?

      response.result.not_nil!
    end

    # Get the value of an object by its key from the store, returning nil if no value is found. See `#store_get`.
    def store_get?(key : String)
      begin
        return store_get key
      rescue e
        return nil
      end
    end

    # Sets a key-value pair in the store to the one passed.
    def store_set(key : String, value : JSON::Any::Type)
      invoke "store.set", JSON::Any.new [JSON::Any.new(key), JSON::Any.new(value)]
    end

    # Deletes a key from the store.
    def store_delete(key : String)
      invoke "store.delete", key
    end

    # Wipes all keys from the store.
    def store_wipe
      invoke "store.wipe", 0 # send a 0, have to send something
    end

    # Returns a list of keys in the store.
    def store_keys : Array(String)
      response = ask "store.keys", 0
      raise RPC::RPCError.new(response.error.not_nil!) unless response.error.nil?

      response.result.not_nil!.as_a.map &.as_s
    end

    # Writes a line of text directly to the Brickadia console.
    def writeln(line : String)
      invoke "writeln", line
    end

    # Broadcasts a message to all players.
    def broadcast(content : String)
      invoke "broadcast", content
    end

    # Whispers a message (`content`) to a specific player (`target`).
    def whisper(target : String, content : String)
      invoke "whisper", {"target" => target, "content" => content}
    end

    # Gets a player's position by their name. Raises if no player exists.
    def get_player_position(target : String) : Vector3
      response = ask "getPlayerPosition", target
      raise RPC::RPCError.new(response.error.not_nil!) unless response.error.nil?
      raise "No player found" if response.result.nil?

      Vector3.new(response.result.not_nil!.as_a.map { |i| (i.as_f? || i.as_i).to_f64 })
    end

    # Gets a player's position by their name, returning nil if no player is found.
    def get_player_position?(target : String) : Vector3?
      begin
        return get_player_position target
      rescue exception
        return nil
      end
    end

    # Returns a list of `{player: Player, position: Vector3}` named tuples representing `Player`-`Vector3` pairs.
    def get_all_player_positions : Array(NamedTuple(player: Player, position: Vector3))
      response = ask "getAllPlayerPositions", 0
      raise RPC::RPCError.new(response.error.not_nil!) unless response.error.nil?

      response.result.not_nil!.as_a.map do |elem|
        e = elem.as_h
        next {player: Player.from_json(e["player"].to_json), position: Vector3.new(e["pos"].as_a.map { |i| (i.as_f? || i.as_i).to_f64 })}
      end
    end

    # Returns a list of players on the server.
    def get_players : Array(Player)
      response = ask "getPlayers", 0
      raise RPC::RPCError.new(response.error.not_nil!) unless response.error.nil?

      response.result.not_nil!.as_a.map { |e| Player.from_json(e.to_json) }
    end

    # todo: role setup (not sure what the return is here)

    # todo: ban list (not sure what the return is here)

    # todo: save list (not sure what the return is here)

    # Get a save path from the name of a save.
    def get_save_path(name : String) : String
      response = ask "getSavePath", name
      raise RPC::RPCError.new(response.error.not_nil!) unless response.error.nil?

      response.result.not_nil!.as_s
    end

    # Get the save data for the current save on the server. Raises if no bricks are on the save.
    def get_save_data : BRS::Save
      response = ask "getSaveData", 0
      raise RPC::RPCError.new(response.error.not_nil!) unless response.error.nil?
      raise "No bricks" if response.result.nil?

      BRS::Save.from_json(response.result.not_nil!.to_json)
    end

    # Get the save data for the current save on the server, returning nil if no bricks are on the save.
    def get_save_data? : BRS::Save?
      begin
        return get_save_data
      rescue exception
        return nil
      end
    end

    # Clears a player's (`target`) bricks. Optionally specify `quiet` to determine the verbosity of the action.
    def clear_bricks(target : String, quiet : Bool = true)
      invoke "clearBricks", {"target" => target, "quiet" => quiet}
    end

    # Clears all bricks. Optionally specify `quiet` to determine the verbosity of the action.
    def clear_all_bricks(quiet : Bool = true)
      invoke "clearAllBricks", quiet
    end

    # Saves all current bricks to a save with the given name.
    def save_bricks(name : String)
      invoke "saveBricks", name
    end

    # Load an already-saved save into the server. Specify `off_x`, `off_y`, and `off_z` to determine the load offset from the origin of the world.
    def load_bricks(name : String, off_x = 0, off_y = 0, off_z = 0, quiet = true)
      invoke "loadBricks", {"name" => name, "offX" => off_x, "offY" => off_y, "offZ" => off_z, "quiet" => quiet}
    end

    # Read the current save data into a `BRS::Save`.
    def read_save_data(name : String) : BRS::Save
      response = ask "readSaveData", name
      raise RPC::RPCError.new(response.error.not_nil!) unless response.error.nil?
      raise "No save" if response.result.nil?

      BRS::Save.from_json(response.result.not_nil!.to_json)
    end

    # Load a `BRS::Save` onto the server. See `#load_bricks`.
    def load_save_data(save : BRS::Save, off_x = 0, off_y = 0, off_z = 0, quiet = true)
      invoke "loadSaveData", {"data" => save, "offX" => off_x, "offY" => off_y, "offZ" => off_z, "quiet" => true}
    end

    # Switch the map to the one specified.
    def change_map(map : String)
      invoke "changeMap", map
    end



    ### BASE LOGIC

    getter wrangler = Log::Wrangler.new

    def initialize
    end

    # Start responding to the Omegga RPC server.
    def start
      loop do
        s = STDIN.gets.not_nil!

        spawn do
          # determine what the payload is
          parsed = JSON.parse(s).as_h

          if parsed.has_key?("method")
            # this is a request or a notification
            method = parsed["method"].as_s
            id_raw = parsed["id"]?
            id = id_raw.nil? ? nil : id_raw.as_s? || id_raw.as_i?

            case method
            when "init"

              init_return = fire_init(parsed["params"].as_h) || RegisteredCommands.new
              response = RPC::Response(RegisteredCommands).new(id, result: init_return)
              respond(response)

            when "stop"

              fire_stop
              respond(RPC::Response(Int32).new(id, result: 0)) # send back a 0 because we have to have *something*

            when "line"

              params = parsed["params"].as_a.map &.as_s
              line = params[0]

              # run through the wrangler first
              @wrangler.handle_line(line)
              fire_line params[0]

            when "start"

              map = parsed["params"].as_a.map(&.as_h)[0]
              fire_start map["map"].as_s

            when "host"

              host = parsed["params"].as_a.map(&.as_h)[0]
              fire_host host["name"].as_s, UUID.new(host["id"].as_s)

            when "version"

              params = parsed["params"].as_a.map &.as_s
              fire_version params[0]

            when "unauthorized"

              fire_unauthorized

            when "join"

              players = parsed["params"].as_a.map { |o| Player.from_json(o.to_json) }
              fire_join players[0]

            when "leave"

              players = parsed["params"].as_a.map { |o| Player.from_json(o.to_json) }
              fire_leave players[0]

            when "chat"

              params = parsed["params"].as_a.map &.as_s
              fire_chat params[0], params[1]

            when .starts_with? "cmd:"
              
              params = parsed["params"].as_a.map &.as_s
              fire_command(method[4..], false, params[0], params[1..])

            when .starts_with? "chatcmd:"

              params = parsed["params"].as_a.map &.as_s
              fire_command(method[8..], true, params[0], params[1..])

            end

          else
            # this is a response
            id_raw = parsed["id"]
            id = id_raw.as_s? || id_raw.as_i?

            raise "Unmatched response ID" unless @channel_map.has_key?(id)

            # build the response and send it
            response = RPC::Response(JSON::Any).from_json(s)
            @channel_map[id].send(response)
          end
        end
      end
    end
  end
end

{% unless flag?("keep_io") %}
  def puts(*objects)
    STDOUT.puts({"jsonrpc" => "2.0", "method": "log", "params": objects.map(&.to_s).join(" ")}.to_json)
  end
{% end %}
