require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

module SpecSupport
  class ConstructorTester
    attr_reader :args
    def initialize(*args) @args = args end
  end
  
  class HasMetadataTester < ActiveRecord::Base
    include HasMetadata
    self.table_name = 'users'
    has_metadata({
      untyped: {},
      can_be_nil: { type: Date, allow_nil: true },
      can_be_nil_with_default: { type: Date, allow_nil: true, default: Date.today },
      can_be_blank: { type: Date, allow_blank: true },
      can_be_blank_with_default: { type: Date, allow_blank: true, default: Date.today },
      cannot_be_nil_with_default: { type: Boolean, allow_nil: false, default: false },
      number: { type: Fixnum, numericality: true },
      boolean: { type: Boolean },
      multiparam: { type: SpecSupport::ConstructorTester },
      has_default: { default: 'default' },
      no_valid: { type: Fixnum, skip_type_validation: true }
    })
  end
  
  class HasMetadataSubclass < HasMetadataTester
    has_metadata(inherited: {})
  end
end

describe HasMetadata do
  describe "#has_metadata" do
    it "should not allow Rails-magic timestamp column names" do
      -> { SpecSupport::HasMetadataTester.has_metadata(created_at: {}) }.should raise_error(/timestamp/)
      -> { SpecSupport::HasMetadataTester.has_metadata(created_on: {}) }.should raise_error(/timestamp/)
      -> { SpecSupport::HasMetadataTester.has_metadata(updated_at: {}) }.should raise_error(/timestamp/)
      -> { SpecSupport::HasMetadataTester.has_metadata(updated_on: {}) }.should raise_error(/timestamp/)
    end
    
    it "should add a :metadata association" do
      SpecSupport::HasMetadataTester.reflect_on_association(:metadata).macro.should eql(:belongs_to)
    end

    it "should set the model to accept nested attributes for :metadata" do
      SpecSupport::HasMetadataTester.nested_attributes_options[:metadata].should_not be_nil
    end
    
    it "should define methods for each field" do
      [ :attribute, :attribute_before_type_cast, :attribute= ].each do |meth|
        SpecSupport::HasMetadataTester.new.should respond_to(meth.to_s.sub('attribute', 'untyped'))
        SpecSupport::HasMetadataTester.new.should respond_to(meth.to_s.sub('attribute', 'multiparam'))
        SpecSupport::HasMetadataTester.new.should respond_to(meth.to_s.sub('attribute', 'number'))
      end
    end
    
    it "should properly handle subclasses" do
      SpecSupport::HasMetadataTester.metadata_fields.should_not include(:inherited)
      SpecSupport::HasMetadataSubclass.metadata_fields.should include(:inherited)
      
      ->{ SpecSupport::HasMetadataTester.new.inherited = true }.should raise_error(NoMethodError)
      sc = SpecSupport::HasMetadataSubclass.new
      sc.inherited = true
      sc.inherited.should be_true
      sc.untyped = 'foo'
      sc.untyped.should eql('foo')
    end
    
    it "should not allow subclasses to redefine metadata fields" do
      -> { SpecSupport::HasMetadataSubclass.has_metadata(untyped: { presence: true }) }.should raise_error(/untyped/)
    end

    [ :attribute, :attribute_before_type_cast ].each do |getter|
      describe "##{getter}" do
        before :each do
          @object = SpecSupport::HasMetadataTester.new
          @metadata = @object.metadata!
        end

        it "should return a field in the metadata object" do
          @metadata.data[:untyped] = 'bar'
          @object.send(getter.to_s.sub('attribute', 'untyped')).should eql('bar')
        end

        it "should return nil if there is no associated metadata" do
          @object.stub!(:metadata).and_return(nil)
          ivars = @object.instance_variables - [ :@metadata ]
          @object.stub!(:instance_variables).and_return(ivars)

          @object.send(getter.to_s.sub('attribute', 'untyped')).should be_nil
        end
      
        it "should return a default if one is specified" do
          @object.send(getter.to_s.sub('attribute', 'has_default')).should eql('default')
        end
      
        it "should return nil if nil is stored and the default is not nil" do
          @metadata.data[:has_default] = nil
          @object.send(getter.to_s.sub('attribute', 'has_default')).should eql(nil)
        end
      end
    end

    describe "#attribute=" do
      before :each do
        @object = SpecSupport::HasMetadataTester.new
        @metadata = @object.metadata!
        @object.boolean = false
        @object.multiparam = SpecSupport::ConstructorTester.new(1,2,3)
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
      
      it "should not enforce a type if :skip_type_validation is true" do
        @object.number = 123
        @object.no_valid = 'not correct'
        @object.should be_valid
      end
      
      it "should cast a type if possible" do
        @object.number = "50"
        @object.should be_valid
        @object.number.should eql(50)
        
        @object.boolean = "1"
        @object.should be_valid
        @object.boolean.should eql(true)
        
        @object.boolean = "0"
        @object.should be_valid
        @object.boolean.should eql(false)
      end
      
      it "should not try to convert integer types to octal" do
        @object.number = "08"
        @object.should be_valid
        @object.number.should eql(8)
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
      
      it "should set to the default if given nil and allow_blank or allow_nil are false" do
        @object.can_be_nil_with_default = nil
        @object.can_be_nil_with_default.should be_nil
        
        @object.can_be_blank_with_default = nil
        @object.can_be_blank_with_default.should be_nil
        
        @object.cannot_be_nil_with_default.should eql(false)
        
        @object.cannot_be_nil_with_default = nil
        @object.should_not be_valid
        @object.errors[:cannot_be_nil_with_default].should_not be_empty
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
    
    describe "#attribute?" do
      before :each do
        @object = SpecSupport::HasMetadataTester.new
        @metadata = @object.metadata!
      end

      context "untyped field" do
        it "should return true if the string is not blank" do
          @metadata.data = { untyped: 'foo' }
          @object.untyped?.should be_true
        end

        it "should return false if the string is blank" do
          @metadata.data = { untyped: ' ' }
          @object.untyped?.should be_false

          @metadata.data = { untyped: '' }
          @object.untyped?.should be_false
        end
      end

      context "numeric field" do
        it "should return true if the number is not zero" do
          @metadata.data = { number: 4 }
          @object.number?.should be_true
        end
        
        it "should return false if the number is zero" do
          @metadata.data = { number: 0 }
          @object.number?.should be_false
        end
      end

      context "typed, non-numeric field" do
        it "should return true if the string is not blank" do
          @metadata.data = { can_be_nil: Date.today }
          @object.can_be_nil?.should be_true
        end
        
        it "should return false if the string is blank" do
          @metadata.data = { can_be_nil: nil }
          @object.can_be_nil?.should be_false
        end
      end
    end
    
    context "[association]" do
      it "should save the metadata when it is changed" do
        object = SpecSupport::HasMetadataTester.new
        object.number = 123
        object.boolean = true
        object.multiparam = SpecSupport::ConstructorTester.new(1,2,3)
        object.metadata.should_receive(:save).once.and_return(true)
        object.save!
      end
    end
    
    describe "#as_json" do
      before :each do
        @object = SpecSupport::HasMetadataTester.new
        @object.number = 123
        @object.boolean = true
      end
      
      it "should include metadata fields" do
        @object.as_json.should eql("has_metadata_tester"=>{
          "id"=>nil,
          'login'=>nil,
          :untyped=>nil,
          :can_be_nil=>nil,
          :can_be_nil_with_default=>Date.today,
          :can_be_blank=>nil,
          :can_be_blank_with_default=>Date.today,
          :cannot_be_nil_with_default=>false,
          :number=>123,
          :boolean=>true,
          :multiparam=>nil,
          :has_default=>"default",
          :no_valid=>nil
        })
      end
      
      it "should not clobber an existing :except option" do
        @object.as_json(except: :untyped).should eql("has_metadata_tester"=>{
          "id"=>nil,
          'login'=>nil,
          :can_be_nil=>nil,
          :can_be_nil_with_default=>Date.today,
          :can_be_blank=>nil,
          :can_be_blank_with_default=>Date.today,
          :cannot_be_nil_with_default=>false,
          :number=>123,
          :boolean=>true,
          :multiparam=>nil,
          :has_default=>"default",
          :no_valid=>nil
        })
        
        @object.as_json(except: [ :untyped, :id ]).should eql("has_metadata_tester"=>{
          'login'=>nil,
          :can_be_nil=>nil,
          :can_be_nil_with_default=>Date.today,
          :can_be_blank=>nil,
          :can_be_blank_with_default=>Date.today,
          :cannot_be_nil_with_default=>false,
          :number=>123,
          :boolean=>true,
          :multiparam=>nil,
          :has_default=>"default",
          :no_valid=>nil
        })
      end
      
      it "should not clobber an existing :methods option" do
        class << @object
          def foo() 1 end
          def bar() '1' end
        end
        
        @object.as_json(methods: :foo).should eql("has_metadata_tester"=>{
          "id"=>nil,
          'login'=>nil,
          :untyped=>nil,
          :can_be_nil=>nil,
          :can_be_nil_with_default=>Date.today,
          :can_be_blank=>nil,
          :can_be_blank_with_default=>Date.today,
          :cannot_be_nil_with_default=>false,
          :number=>123,
          :boolean=>true,
          :multiparam=>nil,
          :has_default=>"default",
          :no_valid=>nil,
          :foo=>1
        })
        
        @object.as_json(methods: [ :foo, :bar ]).should eql("has_metadata_tester"=>{
          "id"=>nil,
          'login'=>nil,
          :untyped=>nil,
          :can_be_nil=>nil,
          :can_be_nil_with_default=>Date.today,
          :can_be_blank=>nil,
          :can_be_blank_with_default=>Date.today,
          :cannot_be_nil_with_default=>false,
          :number=>123,
          :boolean=>true,
          :multiparam=>nil,
          :has_default=>"default",
          :no_valid=>nil,
          :foo=>1,
          :bar=>'1'
        })
      end
    end
    
    describe "#to_xml" do
      before :each do
        @object = SpecSupport::HasMetadataTester.new
        @object.number = 123
        @object.boolean = true
      end
      
      it "should include metadata fields" do
        @object.to_xml.should eql(<<-XML)
<?xml version="1.0" encoding="UTF-8"?>
<has-metadata-tester>
  <id type="integer" nil="true"></id>
  <login nil="true"></login>
  <untyped nil="true"></untyped>
  <can-be-nil nil="true"></can-be-nil>
  <can-be-nil-with-default type="date">#{Date.today.to_s}</can-be-nil-with-default>
  <can-be-blank nil="true"></can-be-blank>
  <can-be-blank-with-default type="date">#{Date.today.to_s}</can-be-blank-with-default>
  <cannot-be-nil-with-default type="boolean">false</cannot-be-nil-with-default>
  <number type="integer">123</number>
  <boolean type="boolean">true</boolean>
  <multiparam nil="true"></multiparam>
  <has-default>default</has-default>
  <no-valid nil="true"></no-valid>
</has-metadata-tester>
        XML
      end
      
      it "should not clobber an existing :except option" do
        @object.to_xml(except: :untyped).should eql(<<-XML)
<?xml version="1.0" encoding="UTF-8"?>
<has-metadata-tester>
  <id type="integer" nil="true"></id>
  <login nil="true"></login>
  <can-be-nil nil="true"></can-be-nil>
  <can-be-nil-with-default type="date">#{Date.today.to_s}</can-be-nil-with-default>
  <can-be-blank nil="true"></can-be-blank>
  <can-be-blank-with-default type="date">#{Date.today.to_s}</can-be-blank-with-default>
  <cannot-be-nil-with-default type="boolean">false</cannot-be-nil-with-default>
  <number type="integer">123</number>
  <boolean type="boolean">true</boolean>
  <multiparam nil="true"></multiparam>
  <has-default>default</has-default>
  <no-valid nil="true"></no-valid>
</has-metadata-tester>
        XML
        
        @object.to_xml(except: [ :untyped, :id ]).should eql(<<-XML)
<?xml version="1.0" encoding="UTF-8"?>
<has-metadata-tester>
  <login nil="true"></login>
  <can-be-nil nil="true"></can-be-nil>
  <can-be-nil-with-default type="date">#{Date.today.to_s}</can-be-nil-with-default>
  <can-be-blank nil="true"></can-be-blank>
  <can-be-blank-with-default type="date">#{Date.today.to_s}</can-be-blank-with-default>
  <cannot-be-nil-with-default type="boolean">false</cannot-be-nil-with-default>
  <number type="integer">123</number>
  <boolean type="boolean">true</boolean>
  <multiparam nil="true"></multiparam>
  <has-default>default</has-default>
  <no-valid nil="true"></no-valid>
</has-metadata-tester>
        XML
      end
      
      it "should not clobber an existing :methods option" do
        class << @object
          def foo() 1 end
          def bar() '1' end
        end
        
        @object.to_xml(methods: :foo).should eql(<<-XML)
<?xml version="1.0" encoding="UTF-8"?>
<has-metadata-tester>
  <id type="integer" nil="true"></id>
  <login nil="true"></login>
  <foo type="integer">1</foo>
  <untyped nil="true"></untyped>
  <can-be-nil nil="true"></can-be-nil>
  <can-be-nil-with-default type="date">#{Date.today.to_s}</can-be-nil-with-default>
  <can-be-blank nil="true"></can-be-blank>
  <can-be-blank-with-default type="date">#{Date.today.to_s}</can-be-blank-with-default>
  <cannot-be-nil-with-default type="boolean">false</cannot-be-nil-with-default>
  <number type="integer">123</number>
  <boolean type="boolean">true</boolean>
  <multiparam nil="true"></multiparam>
  <has-default>default</has-default>
  <no-valid nil="true"></no-valid>
</has-metadata-tester>
        XML
        
        @object.to_xml(methods: [ :foo, :bar ]).should eql(<<-XML)
<?xml version="1.0" encoding="UTF-8"?>
<has-metadata-tester>
  <id type="integer" nil="true"></id>
  <login nil="true"></login>
  <foo type="integer">1</foo>
  <bar>1</bar>
  <untyped nil="true"></untyped>
  <can-be-nil nil="true"></can-be-nil>
  <can-be-nil-with-default type="date">#{Date.today.to_s}</can-be-nil-with-default>
  <can-be-blank nil="true"></can-be-blank>
  <can-be-blank-with-default type="date">#{Date.today.to_s}</can-be-blank-with-default>
  <cannot-be-nil-with-default type="boolean">false</cannot-be-nil-with-default>
  <number type="integer">123</number>
  <boolean type="boolean">true</boolean>
  <multiparam nil="true"></multiparam>
  <has-default>default</has-default>
  <no-valid nil="true"></no-valid>
</has-metadata-tester>
        XML
      end
    end

    context "[dirty]" do
      before :each do
        @object = SpecSupport::HasMetadataTester.create!(untyped: 'foo', number: 123, boolean: true, multiparam: SpecSupport::ConstructorTester.new(1,2,3))
      end

      it "should merge local changes with changed metadata" do
        @object.login = 'me'
        @object.untyped = 'baz'
        @object.changes.should eql('login' => [ nil, 'me' ], 'untyped' => %w( foo baz ))
      end

      it "should clear changed metadata when saved" do
        @object.login = 'me'
        @object.untyped = 'baz'
        @object.save!
        @object.changes.should eql({})
      end

      it "should work when there is no associated metadata" do
        SpecSupport::HasMetadataTester.new(login: 'hello').changes.should eql('login' => [ nil, 'hello' ])
      end
    end
  end
end
