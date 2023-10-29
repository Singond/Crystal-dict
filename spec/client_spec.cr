require "./spec_helper"
require "./test_server"

module DICT
  # Modified Client which enables simulating delay between
  # writing a request and reading a response.
  class SlowClient < Client
    def define(word : String, database : String)
      Log.info { "Sending request '#{word}'" }
      request = Request.new(word, database)
      response_channel = Channel(Response).new
      @requests.send({request: request, channel: response_channel})
      sleep 2 if word == "slow"
      resp = response_channel.receive
      Log.info { "Got response #{resp.to_s.lines()[1]}" }
      resp
    end
  end
end

describe DICT::Client do
  describe "#define" do
    it "retrieves the definition of word" do
      server = TestServer.new
      client = DICT::Client.new(server.io)
      resp = client.define("lattice", "!")
      client.close

      resp.should be_a DICT::DefinitionsResponse
      resp = resp.as DICT::DefinitionsResponse

      d = resp.definitions[0]
      d.status.should eq DICT::Status::DEFINITION
      d.word.should eq "Lattice"
      d.dbname.should eq "gcide"
      d.dbdesc.should eq "The Collaborative International Dictionary of English v.0.48"
      d.body.should match /The arrangement of atoms or molecules/
    end

    it "collapses double dots at the start of a body line" do
      server = TestServer.new
      client = DICT::Client.new(server.io)
      resp = client.define("period", "!")
      client.close

      resp.should be_a DICT::DefinitionsResponse
      resp = resp.as DICT::DefinitionsResponse

      d = resp.definitions[0]
      d.body.lines[0].should eq ".period."
    end

    it "can be called repeatedly" do
      server = TestServer.new
      client = DICT::Client.new(server.io)
      resp1 = client.define("lattice", "!")
      resp2 = client.define("monoclinic", "!")
      client.close

      resp1.should be_a DICT::DefinitionsResponse
      resp2.should be_a DICT::DefinitionsResponse
    end

    it "does not fail if there is no match" do
      client = DICT::Client.new "www.dict.org"
      resp = client.define("abcdefgh", "!")
      client.close

      resp.status.should eq DICT::Status::NO_MATCH
    end
  end

  it "works with LF line endings" do
    server = TestServer.new("\n")
    client = DICT::Client.new(server.io)
    resp = client.define("lattice", "!")
    client.close
    resp.should be_a DICT::DefinitionsResponse
  end

  it "works with tabulators as delimiter in header fields" do
    server = TestServer.new("\n")
    client = DICT::Client.new(server.io)
    resp = client.define("tabulator", "!")
    client.close

    resp.should be_a DICT::DefinitionsResponse
    resp = resp.as DICT::DefinitionsResponse
    resp.definitions.size.should eq 1
  end

  it "works with any sequence of whitespace as delimiter in header fields" do
    server = TestServer.new("\n")
    client = DICT::Client.new(server.io)
    resp = client.define("whitespace", "!")
    client.close

    resp.should be_a DICT::DefinitionsResponse
    resp = resp.as DICT::DefinitionsResponse
    resp.definitions.size.should eq 1
  end

  it "matches correct response to each request" do
    server = TestServer.new
    client = DICT::SlowClient.new(server.io)
    c = Channel(Tuple(String, DICT::Response)).new
    spawn do
      response = client.define("slow", "!")
      c.send({"slow", response})
    end
    spawn do
      response = client.define("lattice", "!")
      c.send({"lattice", response})
    end
    2.times do
      word, response = c.receive
      case word
      when "slow"
        response.to_s.should match /not fast/
      when "lattice"
        response.to_s.should match /arrangement of atoms/
      end
    end
    client.close
  end

  describe "#define", tags: "online" do
    it "retrieves the definition of word" do
      client = DICT::Client.new "www.dict.org"
      resp = client.define("crystal", "!")
      client.close

      resp.should be_a DICT::DefinitionsResponse
      resp = resp.as DICT::DefinitionsResponse

      d = resp.definitions[0]
      d.body.should match /regular form which a substance tends to/
    end

    it "can be called repeatedly" do
      client = DICT::Client.new "www.dict.org"
      resp1 = client.define("crystal", "!")
      resp2 = client.define("ruby", "!")
      client.close

      resp1.should be_a DICT::DefinitionsResponse
      resp2.should be_a DICT::DefinitionsResponse
    end
  end
end

describe DICT::DefinitionResponse do
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
