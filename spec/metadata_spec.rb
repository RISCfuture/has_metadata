require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

RSpec.describe Metadata do
  describe ".new" do
    it "should initialize data to an empty hash" do
      expect(Metadata.new.data).to eql({})
    end

    it "should initialize data to the value given in the initializer" do
      expect(Metadata.new(data: { foo: 'bar' }).data).to eql(foo: 'bar')
    end

    it "should set empty strings to nil" do
      expect(Metadata.create!(data: { foo: '' }).data).to eql(foo: nil)
    end

    it "should not set false values to nil" do
      expect(Metadata.create!(data: { foo: false }).data).to eql(foo: false)
    end
  end

  describe "#changed_metadata" do
    before :each do
      @metadata = Metadata.create!(data: { foo: 'bar', foo1: 'bar1' })
      @metadata.set_fields({ foo: {}, foo1: {} })
    end

    it "should be empty at first" do
      expect(@metadata.changed_metadata).to eql({})
    end

    it "should include changed metadata fields" do
      @metadata.foo = 'baz'
      expect(@metadata.changed_metadata).to eql('foo' => 'bar')
    end

    it "should not include ActiveRecord attributes" do
      @metadata.data = { foo2: 'bar2' }
      expect(@metadata.changed_metadata).to eql({})
    end

    it "should clear when saved" do
      @metadata.foo = 'baz'
      @metadata.save!
      expect(@metadata.changed_metadata).to eql({})
    end
  end
end
