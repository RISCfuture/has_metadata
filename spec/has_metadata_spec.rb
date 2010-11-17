require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

module SpecSupport
  class ConstructorTester
    attr_reader :args
    def initialize(*args) @args = args end
  end
  
  class HasMetadataTester < ActiveRecord::Base
    include HasMetadata
    set_table_name 'users'
    has_metadata({
      untyped: {},
      can_be_nil: { type: Date, allow_nil: true },
      can_be_blank: { type: Date, allow_blank: true },
      number: { numericality: true },
      multiparam: { type: SpecSupport::ConstructorTester },
      has_default: { default: 'default' }
    })
  end
end

describe HasMetadata do
  describe "#has_metadata" do
    it "should add a :metadata association" do
      SpecSupport::HasMetadataTester.reflect_on_association(:metadata).macro.should eql(:belongs_to)
    end

    it "should set the model to accept nested attributes for :metadata" do
      SpecSupport::HasMetadataTester.nested_attributes_options[:metadata].should_not be_nil
    end
    
    it "should make a getter for each field" do
      SpecSupport::HasMetadataTester.new.should respond_to(:untyped)
      SpecSupport::HasMetadataTester.new.should respond_to(:multiparam)
      SpecSupport::HasMetadataTester.new.should respond_to(:number)
    end

    context "getters" do
      before :each do
        @object = SpecSupport::HasMetadataTester.new
        @metadata = @object.metadata!
      end

      it "should return a field in the metadata object" do
        @metadata.data[:untyped] = 'bar'
        @object.untyped.should eql('bar')
      end

      it "should return nil if there is no associated metadata" do
        @object.stub!(:metadata).and_return(nil)
        ivars = @object.instance_variables - [ :@metadata ]
        @object.stub!(:instance_variables).and_return(ivars)

        @object.untyped.should be_nil
      end
      
      it "should return a default if one is specified" do
        @object.has_default.should eql('default')
      end
      
      it "should return nil if nil is stored and the default is not nil" do
        @metadata.data[:has_default] = nil
        @object.has_default.should eql(nil)
      end
    end
    
    it "should make a setter for each field" do
      SpecSupport::HasMetadataTester.new.should respond_to(:untyped=)
      SpecSupport::HasMetadataTester.new.should respond_to(:multiparam=)
      SpecSupport::HasMetadataTester.new.should respond_to(:number=)
    end

    context "setters" do
      before :each do
        @object = SpecSupport::HasMetadataTester.new
        @metadata = @object.metadata!
      end

      it "should set the value in the metadata object" do
        @object.untyped = 'foo'
        @metadata.data[:untyped].should eql('foo')
      end

      it "should create the metadata object if it doesn't exist" do
        @object.stub!(:metadata).and_return(nil)
        ivars = @object.instance_variables - [ :@metadata ]
        @object.stub!(:instance_variables).and_return(ivars)
        Metadata.should_receive(:new).once.and_return(@metadata)
        
        @object.untyped = 'foo'
        @metadata.data[:untyped].should eql('foo')
      end

      it "should enforce a type if given" do
        @object.multiparam = 'not correct'
        @object.should_not be_valid
        @object.errors[:multiparam].should_not be_empty
      end

      it "should not enforce a type if :allow_nil is given" do
        @object.can_be_nil = nil
        @object.valid? #@object.should be_valid
        @object.errors[:can_be_nil].should be_empty
      end

      it "should not enforce a type if :allow_blank is given" do
        @object.can_be_blank = ""
        @object.valid? #@object.should be_valid
        @object.errors[:can_be_blank].should be_empty
      end

      it "should enforce other validations as given" do
        @object.number = 'not number'
        @object.should_not be_valid
        @object.errors[:number].should_not be_empty
      end

      it "should mass-assign a multiparameter attribute" do
        @object.attributes = { 'multiparam(1)' => 'foo', 'multiparam(2)' => '1' }
        @object.multiparam.args.should eql([ 'foo', '1' ])
      end

      it "should compact blank multiparameter parts" do
        @object.attributes = { 'multiparam(1)' => '', 'multiparam(2)' => 'foo' }
        @object.multiparam.args.should eql([ 'foo' ])
      end

      it "should typecast multiparameter parts" do
        @object.attributes = { 'multiparam(1i)' => '1982', 'multiparam(2f)' => '10.5' }
        @object.multiparam.args.should eql([ 1982, 10.5 ])
      end
    end
  end
end
