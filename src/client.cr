require "socket"

require "./status"

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
        banner = build_response @io
        while true
          resp = build_response @io
          if resp
            respch = @responses.receive
            respch.send resp
          end
        end
      end
    end

    # Parses a response from the given _io_.
    def build_response(io : IO)
      status_code_str = io.gets(' ') || raise "Response is empty"
      if status_code = status_code_str.to_i32?
        status = Status.new(status_code)
      else
        raise "Bad response: No status code found in line:\n'#{status_code_str}'"
      end

      case status
      when Status::DEFINITIONS_LIST
        DefinitionsResponse.new(status, io)
      else
        Response.new(status, io)
      end
    end

    def self.parse_body(io : IO)
      String.build do |b|
        until (line = io.gets(chomp: false)) == ".\n"
          b << line
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
    @status : Status
    @status_message : String

    def initialize(@status, io)
      @status_message = io.gets || ""
    end

    def to_s(io : IO)
      io << @status.code << " " << @status_message
    end
  end

  class TextResponse < Response
    @body : String

    def initialize(@status, io)
      super(status, io)
      @body = parse_body(io)
    end

    def to_s(io : IO)
      super(io)
      io << "\n" << @body
    end
  end

  class DefinitionsResponse < Response
    @definitions : Array(String)

    def initialize(@status, io)
      super(status, io)
      parts = @status_message.split(2)
      n = parts[0].to_i32? || raise "Invalid parameter n"
      @definitions = Array.new(size: n) do
        Client.parse_body(io)
      end
    end

    def to_s(io)
      super(io)
      @definitions.each do |definition|
        io << "\n" << definition
      end
    end
  end
end
