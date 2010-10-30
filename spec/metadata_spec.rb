require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe Metadata do
  describe ".new" do
    it "should initialize data to an empty hash" do
      Metadata.new.data.should eql({})
    end

    it "should initialize data to the value given in the initializer" do
      Metadata.new(data: { foo: 'bar' }).data.should eql(foo: 'bar')
    end
  end
end
