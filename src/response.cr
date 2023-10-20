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
      @status_message = io.gets || ""
    end

    # Parses a response from the given _io_.
    def self.build_response(io : IO)
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
        until (line = io.gets) == "."
          b << line << "\n"
        end
      end
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

  class DefinitionsResponse < Response
    getter definitions : Array(DefinitionResponse)

    def initialize(status, io)
      super(status, io)
      parts = @status_message.split(2)
      nstr = parts[0]
      n = nstr.to_i32? || raise "Invalid number of definitions: '#{nstr}'"
      @definitions = Array.new(size: n) do
        DefinitionResponse.new(io)
      end
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

    def initialize(io)
      status_str = io.gets(' ')
      @status = Status.new(status_str.not_nil!.to_i32)
      @word, @dbname, @dbdesc = Response.parse_params(io, 3)
      super(@status, io)
    end
  end
end
