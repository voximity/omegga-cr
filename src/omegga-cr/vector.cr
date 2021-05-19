module Omegga
  struct Vector3
    getter x : Float64
    getter y : Float64
    getter z : Float64

    def self.new(x : Int32, y : Int32, z : Int32)
      new(x.to_f64, y.to_f64, z.to_f64)
    end

    def initialize(@x, @y, @z)
    end

    def initialize(arr : Array(Float64))
      @x = arr[0]
      @y = arr[1]
      @z = arr[2]
    end

    def +(other : Vector3) : self
      Vector3.new(@x + other.x, @y + other.y, @z + other.z)
    end

    def - : self
      Vector3.new(-@x, -@y, -@z)
    end

    def -(other : Vector3) : self
      Vector3.new(@x - other.x, @y - other.y, @z - other.z)
    end

    def *(other : Vector3) : self
      Vector3.new(@x * other.x, @y * other.y, @z * other.z)
    end

    def *(scalar : Float64) : self
      Vector3.new(@x * scalar, @y * scalar, @z * scalar)
    end

    def /(other : Vector3) : self
      Vector3.new(@x / other.x, @y / other.y, @z / other.z)
    end

    def /(scalar : Float64) : self
      Vector3.new(@x / scalar, @y / scalar, @z / scalar)
    end

    def inverse
      Vector3.new(1_f64 / @x, 1_f64 / @y, 1_f64 / @z)
    end

    def dot(other : Vector3) : Float64
      @x * other.x + @y * other.y + @z * other.z
    end

    def magnitude : Float64
      Math.sqrt(@x ** 2 + @y ** 2 + @z ** 2)
    end

    def normalize : self
      self / magnitude
    end

    def cross(other : Vector3) : self
      Vector3.new(
        @y * other.z - @z * other.y,
        @z * other.x - @x * other.z,
        @x * other.y - @y * other.x
      )
    end

    def angle_between(other : Vector3) : Float64
      Math.acos(dot(other) / (magnitude * other.magnitude))
    end

    def abs : self
      Vector3.new(@x.abs, @y.abs, @z.abs)
    end

    def to_s(io)
      io << "(" << @x << ", " << @y << ", " << @z << ")"
    end
  end
end