module Omegga
  class Player
    include JSON::Serializable

    getter name : String
    @id : String
    getter state : String
    getter controller : String

    def id
      UUID.new @id
    end
  end
end