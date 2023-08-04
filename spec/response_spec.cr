require "./spec_helper"
require "./test_server"

describe DICT::DefinitionsResponse do
  it "parses a 150 response correctly" do
    resp = DICT::DefinitionsResponse.new(150, IO::Memory.new(<<-END))
    1 definitions retrieved
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

    resp.status.should eq DICT::Status::DEFINITIONS_LIST
    resp.status_message.should eq "1 definitions retrieved"
    resp = resp.as DICT::DefinitionsResponse
    resp.definitions.size.should eq 1

    d = resp.definitions[0]
    d.status.should eq DICT::Status::DEFINITION
    d.word.should eq "Lattice"
    d.dbname.should eq "gcide"
    d.dbdesc.should eq \
        "The Collaborative International Dictionary of English v.0.48"
    d.body.should start_with "Lattice"
  end
end
