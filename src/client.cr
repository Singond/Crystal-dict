require "log"
require "socket"

require "./request"
require "./response"
require "./status"

module DICT

  class Client
    # Connection to server
    @io : IO
    # Requests created by calls to public client methods
    @requests = Channel(RequestResponse).new
    # A queue of channels to write responses into
    @responses = Channel(ResponsePromise).new
    @banner : BannerResponse?
    @banner_channel = Channel(BannerResponse | Exception).new(capacity: 1)

    def initialize(host : String, port = 2628)
      initialize(TCPSocket.new(host, port))
    end

    # Creates a new `Client` on top of _io_.
    # If _banner_ is set to false, the input stream is expected to begin
    # with a regular response, not with an initial banner (response 220).
    def initialize(@io : IO, banner = true)
      spawn do
        send_requests
      end

      spawn do
        read_responses banner: banner
      end
    end

    private def send_requests
      while req = @requests.receive?
        Log.debug { "Sending request '#{req.request}'" }
        req.request.to_io @io
        @responses.send req.channel
      end
    end

    private def read_responses(*, banner = true)
      expect_banner @io, @banner_channel if banner
      expect_responses @io, @responses
    end

    private def expect_banner(io : IO, target : ResponsePromise)
      bnr = Response.from_io(io)
      if bnr.is_a? BannerResponse
        target.send bnr
      else
        target.send ResponseError.new(bnr, "Connection not successful")
      end
    end

    private def expect_responses(io : IO, targets : Channel(ResponsePromise))
      while respch = targets.receive?
        begin
          resp = Response.from_io_deep io
          if resp
            respch.send resp
          end
        rescue e
          # Propagate exceptions to the main fiber
          # so that user code can handle them.
          respch.send e
        end
      end
    end

    def banner
      if bnr = @banner
        return bnr
      else
        bnr = @banner_channel.receive
        # Re-raise any exception in this fiber
        raise bnr if bnr.is_a? Exception
        @banner = bnr
      end
    end

    def msgid
      banner.msgid
    end

    def capabilities
      banner.capabilities
    end

    private def send(request : Request) : Response
      rr = RequestResponse.new(request)
      @requests.send(rr)
      response = rr.response
      rr.close
      # Re-raise any exception in this fiber
      raise response if response.is_a? Exception
      response
    end

    def define?(word : String, database : String)
      send DefineRequest.new(word, database)
    end

    def define(word : String, database : String)
      response = define?(word, database)
      if !response.is_a? DefinitionResponse
        raise ResponseError.new(response, "Error parsing definition")
      end
      response
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

  alias ResponsePromise = Channel(Response | Exception)

  # A wrapper for a request and the associated response.
  class RequestResponse
    getter request : Request
    getter channel : ResponsePromise

    def initialize(@request, @channel)
    end

    def initialize(@request)
      initialize(request, ResponsePromise.new(capacity: 1))
    end

    def response()
      @channel.receive
    end

    def close()
      @channel.close
    end
  end
end
