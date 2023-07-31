require "spec"
require "http"

require "./spec_helper"
require "./test_server"

module DICT
  # Modified Client which enables simulating delay between
  # writing a request and reading a response.
  class SlowClient < Client
    def define(word : String, database : String)
      puts "Sending request '#{word}'"
      @input.send(Request.new(word, database))
      sleep 2 if word == "slow"
      resp = @output.receive
      puts "Got response #{resp}"
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
      resp.@body.should match /The arrangement of atoms or molecules/
    end

    pending "matches correct response to each request" do
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
end
