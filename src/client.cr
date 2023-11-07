require "socket"

require "./request"
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
    @banner : BannerResponse?
    @banner_channel = Channel(BannerResponse).new(capacity: 1)

    def initialize(host : String, port = 2628)
      initialize(TCPSocket.new(host, port))
    end

    def initialize(@io : IO)
      spawn do
        send_requests
      end

      spawn do
        read_responses
      end
    end

    private def send_requests
      while req = @requests.receive?
        req[:request].to_io @io
        @responses.send req[:channel]
      end
    end

    private def read_responses
      expect_banner @io, @banner_channel
      expect_responses @io, @responses
    end

    private def expect_banner(io : IO, target : Channel(Response))
      bnr = Response.from_io(io)
      if bnr.is_a? BannerResponse
        target.send bnr
      else
        raise ResponseError.new bnr, "Connection not successful"
      end
    end

    private def expect_responses(io : IO, targets : Channel(Channel(Response)))
      while respch = targets.receive?
        resp = Response.from_io_deep io
        if resp
          respch.send resp
        end
      end
    end

    def banner
      if bnr = @banner
        return bnr
      else
        bnr = @banner_channel.receive
        @banner = bnr
      end
    end

    def msgid
      banner.msgid
    end

    def capabilities
      banner.capabilities
    end

    private def send(request : Request)
      response_channel = Channel(Response).new(capacity: 1)
      @requests.send({request: request, channel: response_channel})
      response = response_channel.receive
      response_channel.close
      response
    end

    def define(word : String, database : String)
      send DefineRequest.new(word, database)
    end

    def close
      resp = send QuitRequest.new
      # TODO: Check response
      close_self
    end

    private def close_self
      @io.close
      @requests.close
      @responses.close
    end
  end
end
