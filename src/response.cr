require "log"

module DICT

  # A general representation of a response in the DICT protocol.
  #
  # Every response contains at least a three-digit status code
  # and usually also a status text on the same line.
  # This class represents responses consisting only of the status
  # code and status text (so-called "status responses" in the protocol).
  # Other features of responses, like parameters in the status text
  # or a textual body, are represented by subclasses of this type.
  class Response
    getter status : Status
    getter status_message : String

    def initialize(status : Status | Number, io : IO)
      case status
      in Status
        @status = status
      in Number
        @status = Status.new(status)
      end
      if msg = io.gets
        @status_message = msg.lstrip
      else
        @status_message = ""
      end
    end

    # Parses a response from the given _io_.
    def self.from_io(io : IO)
      Log.debug { "Parsing response..." }
      status_code_str = io.gets(3) || raise "Response is empty"
      if status_code = status_code_str.to_i32?
        status = Status.new(status_code)
        Log.debug { "Read status #{status}" }
      else
        raise "Bad response: No status code found in line:\n'#{status_code_str}'"
      end

      case status
      when Status::BANNER
        resp = BannerResponse.new(status, io)
      when Status::DEFINITIONS_LIST
        resp = DefinitionsResponse.new(status, io)
      when Status::DEFINITION
        resp = DefinitionResponse.new(status, io)
      else
        resp = Response.new(status, io)
      end
      Log.debug { "Successfully parsed response #{resp.status.code}" }
      resp
    end

    # Parses a response and the appropriate continuation responses
    # from the given _io_.
    def self.from_io_deep(io : IO)
      resp = Response.from_io(io)
      resp.from_io_more(io)
      resp
    end

    def self.parse_body(io : IO)
      Log.debug { "Parsing response body" }
      body = String.build do |b|
        # Single period on its own indicates the end of body.
        until (line = io.gets) == "."
          # Initial double period must be collapsed into single.
          # The server doubles initial period to distinguish the line
          # from the end-of-body marker.
          if line && line.starts_with? ".."
            line = line[1..]
          end
          b << line << "\n"
        end
      end
      Log.debug { "Parsed #{body.lines.size} body lines" }
      body
    end

    def self.parse_params(io : IO, n : Number)
      Array(String).new(n) do |idx|
        String.build do |str|

          # Skip whitespace
          while (c = io.read_char) && c.whitespace?
            # Line must not end before all parameters have been read.
            if (c == '\n' || c == '\r') && idx < n - 1
              raise "Missing #{idx}th parameter"
            end
            # Skip the character
          end

          if !c
            raise "Input ended before #{idx+1} parameters could be read"
          end

          # Read word or quoted string
          if c == '"'
            # quoted string
            while (c = io.read_char) && c != '"'
              if c == '\n' || c == '\r'
                raise "Line ended before quoted string ended"
              end
              str << c
            end
          else
            # word
            str << c
            while (c = io.read_char) && !c.whitespace?
              str << c
            end
          end

        end
      end
    end

    def self.parse_params(string : String, n : Number)
      self.parse_params(String.Builder.new(string), n)
    end

    # Parses continuation responses expected after this response from _io_.
    # This default implementation does nothing.
    def from_io_more(io : IO)
    end

    def to_s(io : IO)
      io << @status.code << " " << @status_message
    end
  end

  # A response containing a textual body.
  class TextResponse < Response
    getter body : String

    def initialize(status, io)
      super(status, io)
      @body = Response.parse_body(io)
    end

    def to_s(io : IO)
      super(io)
      io << "\n" << @body
    end
  end

  class BannerResponse < Response
    @capabilities : Array(String)
    getter msgid : String

    def initialize(status, io)
      unless status == Status::BANNER
        raise ArgumentError.new "Invalid status: #{status}"
      end
      super(status, io)
      @msgid, @capabilities = parse_params @status_message
    end

    private def parse_params(status_message)
      words = status_message.split
      msgid = words[-1]? || ""
      c = words[-2]?
      if c && c.starts_with?('<') && c.ends_with?('>')
        c = c[1...-1]
        capabilities = c.split('.')
      else
        capabilities = [] of String
      end
      {msgid, capabilities}
    end

    def capabilities
      @capabilities.clone
    end
  end

  class DefinitionsResponse < Response
    getter definitions = Array(DefinitionResponse).new

    def initialize(status, io)
      super(status, io)
    end

    def from_io_more(io)
      if @status == Status::DEFINITIONS_LIST
        @definitions = parse_children(io)
      elsif @status == Status::NO_MATCH
        @definitions = [] of DefinitionResponse
      else
        raise ArgumentError.new "Invalid status: #{status}"
      end
    end

    private def parse_children(io)
      parts = @status_message.split(2)
      nstr = parts[0]
      n = nstr.to_i32? || raise "Invalid number of definitions: '#{nstr}'"

      # Individual definitions
      Log.debug { "Parsing #{n} definitions" }
      definitions = Array(DefinitionResponse).new(initial_capacity: n)
      n.times do
        resp = Response.from_io(io)
        if resp.is_a? DefinitionResponse
          definitions << resp
        else
          raise ResponseError.new resp, "Cannot parse definition"
        end
      end

      # Completion marker
      Log.debug { "Parsing definitions completion response" }
      final = Response.from_io(io)
      unless final.status == Status::OK
        raise ResponseError.new final,
          "Definition command not completed successfully"
      end

      definitions
    end

    def to_s(io)
      super(io)
      @definitions.each do |definition|
        io << "\n" << definition
      end
    end
  end

  class DefinitionResponse < TextResponse
    getter word : String
    getter dbname : String
    getter dbdesc : String

    def initialize(status, io)
      super(status, io)
      msgio = IO::Memory.new(@status_message)
      @word, @dbname, @dbdesc = Response.parse_params(msgio, 3)
    end
  end

  class ResponseError < Exception
    getter response : Response

    def initialize(@response, message : String? = nil)
      super("#{message}#{message ? ": " : ""}Unexpected response: \
        #{response.status.code} #{response.status_message}")
    end
  end
end
