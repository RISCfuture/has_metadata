require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe Metadata do
  describe ".new" do
    it "should initialize data to an empty hash" do
      Metadata.new.data.should eql({})
    end

    it "should initialize data to the value given in the initializer" do
      Metadata.new(data: { foo: 'bar' }).data.should eql(foo: 'bar')
    end

    it "should set empty strings to nil" do
      Metadata.create!(data: { foo: '' }).data.should eql(foo: nil)
    end

    it "should not set false values to nil" do
      Metadata.create!(data: { foo: false }).data.should eql(foo: false)
    end
  end

  describe "#changed_metadata" do
    before :each do
      @metadata = Metadata.create!(data: { foo: 'bar', foo1: 'bar1' })
      @metadata.set_fields({ foo: {}, foo1: {} })
    end

    it "should be empty at first" do
      @metadata.changed_metadata.should eql({})
    end

    it "should include changed metadata fields" do
      @metadata.foo = 'baz'
      @metadata.changed_metadata.should eql('foo' => 'bar')
    end

    it "should not include ActiveRecord attributes" do
      @metadata.data = { foo2: 'bar2' }
      @metadata.changed_metadata.should eql({})
    end

    it "should clear when saved" do
      @metadata.foo = 'baz'
      @metadata.save!
      @metadata.changed_metadata.should eql({})
    end
  end
end
