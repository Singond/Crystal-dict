require "socket"

module DICT

  alias RequestResponse = {request: Request, channel: Channel(Response)}

  class Client
    # Connection to server
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
        while req = @requests.receive
          @io << req[:request]
          @responses.send req[:channel]
        end
      end

      spawn do
        while true
          body = String.build do |r|
            until (line = @io.gets(chomp: false)) == ".\n"
              r << line
            end
          end
          unless body.empty?
            resp = Response.new(body)
            respch = @responses.receive
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

  class Response
    @body : String

    def initialize(@body)
    end

    def to_s(io : IO)
      io << @body
    end
  end
end
