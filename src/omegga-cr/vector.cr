module Omegga
  struct Vector3
    getter x : Float64
    getter y : Float64
    getter z : Float64

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

    def normalize : Vector3
      self / magnitude
    end

    def to_s(io)
      io << "(" << @x << ", " << @y << ", " << @z << ")"
    end
  end
end