module Omegga::RPC
  extend self

  alias Id = String | Int32 | Nil

  class RPCError < Exception
    getter error : Error

    def initialize(@error)
      super(@error.message)
    end
  end

  class Notification(T)
    include JSON::Serializable

    property jsonrpc = "2.0"
    property method : String
    property params : T

    def initialize(@method, @params)
    end
  end

  class Request(T) < Notification(T)
    property id : Id

    def initialize(@method, @params, @id)
    end
  end

  class Response(T)
    include JSON::Serializable

    property jsonrpc = "2.0"
    property result : T?
    property error : Error?
    property id : Id

    def initialize(@id, @result = nil, @error = nil)
    end
  end

  class Error
    include JSON::Serializable

    property code : Int32
    property message : String
    property data : JSON::Any?
  end
end