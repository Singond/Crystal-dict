require "./spec_helper"
require "./test_server"

module DICT
  # Modified Client which enables simulating delay between
  # writing a request and reading a response.
  class SlowClient < Client
    def define(word : String, database : String)
      puts "Sending request '#{word}'"
      request = Request.new(word, database)
      response_channel = Channel(Response).new
      @requests.send({request: request, channel: response_channel})
      sleep 2 if word == "slow"
      resp = response_channel.receive
      puts "Got response #{resp.to_s.lines()[1]}"
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

      resp.should be_a DICT::DefinitionsResponse
      resp = resp.as DICT::DefinitionsResponse

      d = resp.definitions[0]
      d.body.should match /The arrangement of atoms or molecules/
    end
  end

  it "works with LF line endings" do
    server = TestServer.new("\n")
    client = DICT::Client.new(server.io)
    resp = client.define("lattice", "!")
    resp.should be_a DICT::DefinitionsResponse
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
  end
end
