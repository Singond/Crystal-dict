require "./spec_helper"
require "./test_server"

describe DICT::Response do
  it "parses a 150 response sequence correctly" do
    resp = DICT::Response.from_io_deep(IO::Memory.new(<<-END))
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
    250 ok

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

  it "parses a sequence of positive responses correctly" do
    resp = DICT::Response.from_io_deep(IO::Memory.new(<<-END))
    150 2 definitions retrieved
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
    151 "lattice" wn "WordNet (r) 3.0 (2006)"
    lattice
      n 1: an arrangement of points or particles or objects in a
           regular periodic pattern in 2 or 3 dimensions
      2: framework consisting of an ornamental design made of strips
         of wood or metal [syn: {lattice}, {latticework}, {fretwork}]
    .
    250 ok

    END

    resp.status.should eq DICT::Status::DEFINITIONS_LIST
    resp.status_message.should eq "2 definitions retrieved"
    resp = resp.as DICT::DefinitionsResponse
    resp.definitions.size.should eq 2

    d = resp.definitions[0]
    d.status.should eq DICT::Status::DEFINITION
    d.word.should eq "Lattice"
    d.dbname.should eq "gcide"
    d.dbdesc.should eq \
        "The Collaborative International Dictionary of English v.0.48"
    d.body.should start_with "Lattice"

    d = resp.definitions[1]
    d.status.should eq DICT::Status::DEFINITION
    d.word.should eq "lattice"
    d.dbname.should eq "wn"
    d.dbdesc.should eq "WordNet (r) 3.0 (2006)"
    d.body.should start_with "lattice"
  end
end

describe DICT::DefinitionResponse do
  it "parses a 151 response correctly" do
    resp = DICT::DefinitionResponse.new(151, IO::Memory.new(<<-END))
    "Lattice" gcide "The Collaborative International Dictionary of English v.0.48"
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

    resp.status.should eq DICT::Status::DEFINITION
    d = resp.as DICT::DefinitionResponse
    d.word.should eq "Lattice"
    d.dbname.should eq "gcide"
    d.dbdesc.should eq \
        "The Collaborative International Dictionary of English v.0.48"
    d.body.should start_with "Lattice"
  end

  it "prints correct status message" do
    server = TestServer.new("\n")
    client = DICT::Client.new(server.io)
    resp = client.define("lattice", "!")
    client.close

    resp.should be_a DICT::DefinitionsResponse
    resp = resp.as DICT::DefinitionsResponse
    d = resp.definitions[0]
    d.to_s.lines[0].should eq %(151 "Lattice" gcide \
      "The Collaborative International Dictionary of English v.0.48")
  end
end
