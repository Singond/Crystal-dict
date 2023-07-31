class TestServer
  @@words = Hash(String, String).new

  def initialize
    @in, @inw = IO.pipe
    @outr, @out = IO.pipe
    spawn do
      run
    end
  end

  def io
    IO::Stapled.new(@outr, @inw)
  end

  def run
    @out << "220 localhost testing server <auth.mime> <ok@localhost>\n\n"
    while req = @in.gets
      if req =~ /define ! ([a-z]+)/
        word = $~[1]
        if @@words.has_key? word
          @out << @@words[word] << "\n.\n"
          puts "Sent response to '#{word}' (#{@@words[word].size} characters)"
        else
          @out << "552 No match" << "\n.\n"
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
end
