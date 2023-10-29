module DICT

  abstract class Request
  end

  class DefineRequest < Request
    @word : String
    @database : String

    def initialize(@word, @database)
    end

    def to_s(io : IO)
      io << "define #{@database} #{@word}\r\n"
    end
  end

  class QuitRequest < Request
    def to_s(io : IO)
      io << "quit\r\n"
    end
  end
end
