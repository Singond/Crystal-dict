require "socket"

module DICT
  class Client
    # Connection to server
    @io : IO
    # Requests created by calling client methods
    @input = Channel(Request).new
    # Responses read from server
    @output = Channel(Response).new

    def initialize(host : String, port = 2628)
      initialize(TCPSocket.new(host, port))
    end

    def initialize(@io : IO)
      spawn do
        while req = @input.receive
          @io << req
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
            @output.send(Response.new(body))
          end
        end
      end
    end

    def define(word : String, database : String)
      @input.send(Request.new(word, database))
      @output.receive
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
