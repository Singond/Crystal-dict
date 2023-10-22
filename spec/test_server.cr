require "./spec_helper"

class TestServer
  @@words = Hash(String, String).new
  @eol = "\r\n"

  def initialize
    @in, @inw = IO.pipe
    @outr, @out = IO.pipe
    spawn do
      run
    end
  end

  def initialize(@eol : String)
    initialize
  end

  def io
    IO::Stapled.new(@outr, @inw)
  end

  def run
    @out << "220 localhost testing server <auth.mime> <ok@localhost>"
    @out << @eol
    while req = @in.gets
      if req =~ /define ! ([a-z]+)/
        word = $~[1]
        if @@words.has_key? word
          @out << @@words[word] << @eol
          Log.info do
            "Sent response to '#{word}' (#{@@words[word].size} characters)"
          end
        else
          @out << "552 No match" << @eol << "." << @eol
        end
      end
    end
  end

  @@words["lattice"] = <<-END
  150 1 definitions retrieved
  151 "Lattice" gcide "The Collaborative International Dictionary of English v.0.48"
  Lattice \\Lat"tice\\, n. [OE. latis, F. lattis lathwork, fr. latte
    lath. See {Latten}, 1st {Lath}.]
    1. (Crystallography) The arrangement of atoms or molecules in
      a crystal, represented as a repeating arrangement of
      points in space, each point representing the location of
      an atom or molecule; called also {crystal lattice} and
      {space lattice}.
      [PJC]
  .
  END

  @@words["monoclinic"] = <<-END
  150 1 definitions retrieved
  151 "monoclinic" wn "WordNet (r) 3.0 (2006)"
  monoclinic
      adj 1: having three unequal crystal axes with one oblique
            intersection; "monoclinic system" [ant: {anorthic},
            {triclinic}]
  .
  END

  @@words["slow"] = <<-END
  150 1 definitions retrieved
  151 "slow" md "My Dictionary 0.4"
  slow
      adj 1. not fast
  .
  END

  @@words["tabulator"] = <<-END
  150\t1\tdefinitions retrieved
  151\t"tabulator"\tmd\t"My Dictionary 0.4"
  tabulator
      noun 1. The ASCII character U+0009
  .
  END

  @@words["whitespace"] = <<-END
  150  1       definitions retrieved
  151\t "whitespace"     md  \t  "My Dictionary 0.4"
  whitespace
      noun 1. A non-printable character
  .
  END

  @@words["period"] = <<-END
  150 1 definition retrieved
  151 "period" foldoc "The Free On-line Dictionary of Computing"
  ..period.
      1. A non-printable character.
      2. (US) A full stop, like so:
  .
  END
end
