require "../src/status"
require "./spec_helper"

describe DICT::Status do
  it "parses status code" do
    status = DICT::Status.new(150)
    status.should eq DICT::Status::DEFINITIONS_LIST
  end
end
