module Omegga::BRS
  class User
    include JSON::Serializable

    def self.default
      User.new(UUID.new("00000000-0000-0000-0000-000000000000"), "Unknown")
    end

    property id : UUID
    property name : String

    def initialize(@id, @name)
    end
  end

  class BrickOwner < User
    property bricks : Int32

    def initialize(@id, @name, @bricks)
    end
  end

  class Component
    include JSON::Serializable

    property version : Int32
    property brick_indices : Array(Int32)
    property properties : Hash(String, String | Int32 | Float64)
  end

  struct Vector
    def self.new(pull : JSON::PullParser)
      pull.read_begin_array
      x = pull.read_int
      y = pull.read_int
      z = pull.read_int
      pull.read_end_array
      new(x.to_i32, y.to_i32, z.to_i32)
    end

    def self.new(v : Vector3)
      new(v.x.round.to_i32, v.y.round.to_i32, v.z.round.to_i32)
    end

    getter x : Int32
    getter y : Int32
    getter z : Int32

    def initialize(@x, @y, @z)
    end

    def to_v3 : Vector3
      Vector3.new(@x.to_f64, @y.to_f64, @z.to_f64)
    end

    def to_json(builder : JSON::Builder)
      builder.array do
        builder.number @x
        builder.number @y
        builder.number @z
      end
    end
  end

  enum Direction
    XPositive
    XNegative
    YPositive
    YNegative
    ZPositive
    ZNegative
  end

  enum Rotation
    Deg0
    Deg90
    Deg180
    Deg270
  end

  struct Collision
    include JSON::Serializable

    getter player : Bool = true
    getter weapon : Bool = true
    getter interaction : Bool = true
    getter tool : Bool = true

    def initialize
    end

    def initialize(*, @player, @weapon, @interaction, @tool)
    end
  end

  class Brick
    include JSON::Serializable

    property asset_name_index : Int32 = 0
    property size : Vector = Vector.new(0, 0, 0)
    property position : Vector = Vector.new(0, 0, 0)

    @[JSON::Field(converter: Enum::ValueConverter(BRS::Direction))]
    property direction : Direction = Direction::ZPositive
    
    @[JSON::Field(converter: Enum::ValueConverter(BRS::Rotation))]
    property rotation : Rotation = Rotation::Deg0

    property collision : Collision = Collision.new
    property visibility : Bool = true
    property material_index : Int32 = 0
    property physical_index : Int32 = 0
    property material_intensity : Int32 = 0
    property color : Int32 | Array(UInt8) = 0
    property owner_index : Int32 = 0
    property components : Hash(String, Hash(String, String | Int32 | Float64)) = {} of String => Hash(String, String | Int32 | Float64)

    def initialize
    end
  end

  class Save
    include JSON::Serializable

    property version : Int32 = 10
    property map : String = "Unknown"
    property author : User = User.default
    property host : User = User.default
    property description : String = ""
    
    # property save_time : Array(Int32) = [0, 0, 0, 0, 0, 0, 0, 0]
    
    property mods : Array(String) = [] of String
    property brick_assets : Array(String) = ["PB_DefaultBrick"]
    property colors : Array(Array(UInt8)) = [] of Array(UInt8)
    property physical_materials : Array(String) = [] of String
    property materials : Array(String) = [] of String
    property brick_owners : Array(BrickOwner) = [] of BrickOwner
    property components : Hash(String, Component) = {} of String => Component
    property bricks : Array(Brick) = [] of Brick

    def brick_count
      bricks.size
    end
  end
end