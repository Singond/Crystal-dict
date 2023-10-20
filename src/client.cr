require "socket"

require "./response"
require "./status"

module DICT

  alias RequestResponse = {request: Request, channel: Channel(Response)}

  class Client
    # Connection to server
    @io : IO
    # Requests created by calls to public client methods
    @requests = Channel(RequestResponse).new
    # A queue of channels to write responses into
    @responses = Channel(Channel(Response)).new

    def initialize(host : String, port = 2628)
      initialize(TCPSocket.new(host, port))
    end

    def initialize(@io : IO)
      spawn do
        while req = @requests.receive?
          @io << req[:request]
          @responses.send req[:channel]
        end
      end

      spawn do
        banner = Response.build_response @io
        while respch = @responses.receive?
          resp = Response.build_response @io
          if resp
            respch.send resp
          end
        end
      end
    end

    def define(word : String, database : String)
      request = Request.new(word, database)
      response_channel = Channel(Response).new(capacity: 1)
      @requests.send({request: request, channel: response_channel})
      response = response_channel.receive
      response_channel.close
      response
    end

    def close
      @io.close
      @requests.close
      @responses.close
    end
  end

  class Request
    @word : String
    @database : String

    def initialize(@word, @database)
    end

    def to_s(io : IO)
      io << "define #{@database} #{@word}\n\n"
    end
  end
end
