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
                     untyped:                    {},
                     can_be_nil:                 { type: Date, allow_nil: true },
                     can_be_nil_with_default:    { type: Date, allow_nil: true, default: Date.today },
                     can_be_blank:               { type: Date, allow_blank: true },
                     can_be_blank_with_default:  { type: Date, allow_blank: true, default: Date.today },
                     cannot_be_nil_with_default: { type: Boolean, allow_nil: false, default: false },
                     number:                     { type: Fixnum, numericality: true },
                     boolean:                    { type: Boolean },
                     multiparam:                 { type: SpecSupport::ConstructorTester },
                     has_default:                { default: 'default' },
                     no_valid:                   { type: Fixnum, skip_type_validation: true }
                 })
  end

  class HasMetadataSubclass < HasMetadataTester
    has_metadata(inherited: {})
  end
end

describe HasMetadata do
  describe "#has_metadata" do
    it "should not allow Rails-magic timestamp column names" do
      expect { SpecSupport::HasMetadataTester.has_metadata(created_at: {}) }.to raise_error(/timestamp/)
      expect { SpecSupport::HasMetadataTester.has_metadata(created_on: {}) }.to raise_error(/timestamp/)
      expect { SpecSupport::HasMetadataTester.has_metadata(updated_at: {}) }.to raise_error(/timestamp/)
      expect { SpecSupport::HasMetadataTester.has_metadata(updated_on: {}) }.to raise_error(/timestamp/)
    end

    it "should add a :metadata association" do
      expect(SpecSupport::HasMetadataTester.reflect_on_association(:metadata).macro).to eql(:belongs_to)
    end

    it "should set the model to accept nested attributes for :metadata" do
      expect(SpecSupport::HasMetadataTester.nested_attributes_options[:metadata]).not_to be_nil
    end

    it "should define methods for each field" do
      [:attribute, :attribute_before_type_cast, :attribute=].each do |meth|
        expect(SpecSupport::HasMetadataTester.new).to respond_to(meth.to_s.sub('attribute', 'untyped'))
        expect(SpecSupport::HasMetadataTester.new).to respond_to(meth.to_s.sub('attribute', 'multiparam'))
        expect(SpecSupport::HasMetadataTester.new).to respond_to(meth.to_s.sub('attribute', 'number'))
      end
    end

    it "should properly handle subclasses" do
      expect(SpecSupport::HasMetadataTester.metadata_fields).not_to include(:inherited)
      expect(SpecSupport::HasMetadataSubclass.metadata_fields).to include(:inherited)

      expect { SpecSupport::HasMetadataTester.new.inherited = true }.to raise_error(NoMethodError)
      sc           = SpecSupport::HasMetadataSubclass.new
      sc.inherited = true
      expect(sc.inherited).to be_true
      sc.untyped = 'foo'
      expect(sc.untyped).to eql('foo')
    end

    it "should not allow subclasses to redefine metadata fields" do
      expect { SpecSupport::HasMetadataSubclass.has_metadata(untyped: { presence: true }) }.to raise_error(/untyped/)
    end

    [:attribute, :attribute_before_type_cast].each do |getter|
      describe "##{getter}" do
        before :each do
          @object   = SpecSupport::HasMetadataTester.new
          @metadata = @object.metadata!
        end

        it "should return a field in the metadata object" do
          @metadata.data[:untyped] = 'bar'
          expect(@object.send(getter.to_s.sub('attribute', 'untyped'))).to eql('bar')
        end

        it "should return nil if there is no associated metadata" do
          allow(@object).to receive(:metadata).and_return(nil)
          ivars = @object.instance_variables - [:@metadata]
          allow(@object).to receive(:instance_variables).and_return(ivars)

          expect(@object.send(getter.to_s.sub('attribute', 'untyped'))).to be_nil
        end

        it "should return a default if one is specified" do
          expect(@object.send(getter.to_s.sub('attribute', 'has_default'))).to eql('default')
        end

        it "should return nil if nil is stored and the default is not nil" do
          @metadata.data[:has_default] = nil
          expect(@object.send(getter.to_s.sub('attribute', 'has_default'))).to eql(nil)
        end
      end
    end

    describe "#attribute=" do
      before :each do
        @object            = SpecSupport::HasMetadataTester.new
        @metadata          = @object.metadata!
        @object.boolean    = false
        @object.multiparam = SpecSupport::ConstructorTester.new(1, 2, 3)
      end

      it "should set the value in the metadata object" do
        @object.untyped = 'foo'
        expect(@metadata.data[:untyped]).to eql('foo')
      end

      it "should create the metadata object if it doesn't exist" do
        allow(@object).to receive(:metadata).and_return(nil)
        ivars = @object.instance_variables - [:@metadata]
        allow(@object).to receive(:instance_variables).and_return(ivars)
        expect(Metadata).to receive(:new).once.and_return(@metadata)

        @object.untyped = 'foo'
        expect(@metadata.data[:untyped]).to eql('foo')
      end

      it "should enforce a type if given" do
        @object.multiparam = 'not correct'
        expect(@object).not_to be_valid
        expect(@object.errors[:multiparam]).not_to be_empty
      end

      it "should not enforce a type if :skip_type_validation is true" do
        @object.number   = 123
        @object.no_valid = 'not correct'
        expect(@object).to be_valid
      end

      it "should cast a type if possible" do
        @object.number = "50"
        expect(@object).to be_valid
        expect(@object.number).to eql(50)

        @object.boolean = "1"
        expect(@object).to be_valid
        expect(@object.boolean).to eql(true)

        @object.boolean = "0"
        expect(@object).to be_valid
        expect(@object.boolean).to eql(false)
      end

      it "should not try to convert integer types to octal" do
        @object.number = "08"
        expect(@object).to be_valid
        expect(@object.number).to eql(8)
      end

      it "should not enforce a type if :allow_nil is given" do
        @object.can_be_nil = nil
        @object.valid? #@object.should be_valid
        expect(@object.errors[:can_be_nil]).to be_empty
      end

      it "should not enforce a type if :allow_blank is given" do
        @object.can_be_blank = ""
        @object.valid? #@object.should be_valid
        expect(@object.errors[:can_be_blank]).to be_empty
      end

      it "should set to the default if given nil and allow_blank or allow_nil are false" do
        @object.can_be_nil_with_default = nil
        expect(@object.can_be_nil_with_default).to be_nil

        @object.can_be_blank_with_default = nil
        expect(@object.can_be_blank_with_default).to be_nil

        expect(@object.cannot_be_nil_with_default).to eql(false)

        @object.cannot_be_nil_with_default = nil
        expect(@object).not_to be_valid
        expect(@object.errors[:cannot_be_nil_with_default]).not_to be_empty
      end

      it "should enforce other validations as given" do
        @object.number = 'not number'
        expect(@object).not_to be_valid
        expect(@object.errors[:number]).not_to be_empty
      end

      it "should mass-assign a multiparameter attribute" do
        @object.attributes = { 'multiparam(1)' => 'foo', 'multiparam(2)' => '1' }
        expect(@object.multiparam.args).to eql(['foo', '1'])
      end

      it "should compact blank multiparameter parts" do
        @object.attributes = { 'multiparam(1)' => '', 'multiparam(2)' => 'foo' }
        expect(@object.multiparam.args).to eql(['foo'])
      end

      it "should typecast multiparameter parts" do
        @object.attributes = { 'multiparam(1i)' => '1982', 'multiparam(2f)' => '10.5' }
        expect(@object.multiparam.args).to eql([1982, 10.5])
      end
    end

    describe "#attribute?" do
      before :each do
        @object   = SpecSupport::HasMetadataTester.new
        @metadata = @object.metadata!
      end

      context "untyped field" do
        it "should return true if the string is not blank" do
          @metadata.data = { untyped: 'foo' }
          expect(@object.untyped?).to be_true
        end

        it "should return false if the string is blank" do
          @metadata.data = { untyped: ' ' }
          expect(@object.untyped?).to be_false

          @metadata.data = { untyped: '' }
          expect(@object.untyped?).to be_false
        end
      end

      context "numeric field" do
        it "should return true if the number is not zero" do
          @metadata.data = { number: 4 }
          expect(@object.number?).to be_true
        end

        it "should return false if the number is zero" do
          @metadata.data = { number: 0 }
          expect(@object.number?).to be_false
        end
      end

      context "typed, non-numeric field" do
        it "should return true if the string is not blank" do
          @metadata.data = { can_be_nil: Date.today }
          expect(@object.can_be_nil?).to be_true
        end

        it "should return false if the string is blank" do
          @metadata.data = { can_be_nil: nil }
          expect(@object.can_be_nil?).to be_false
        end
      end
    end

    context "[association]" do
      it "should save the metadata when it is changed" do
        object            = SpecSupport::HasMetadataTester.new
        object.number     = 123
        object.boolean    = true
        object.multiparam = SpecSupport::ConstructorTester.new(1, 2, 3)
        expect(object.metadata).to receive(:save).once.and_return(true)
        object.save!
      end
    end

    describe "#as_json" do
      before :each do
        @object         = SpecSupport::HasMetadataTester.new
        @object.number  = 123
        @object.boolean = true
      end

      it "should include metadata fields" do
        expect(@object.as_json).to eql(
            'id'                         => nil,
            'login'                      => nil,
            'untyped'                    => nil,
            'can_be_nil'                 => nil,
            'can_be_nil_with_default'    => Date.today,
            'can_be_blank'               => nil,
            'can_be_blank_with_default'  => Date.today,
            'cannot_be_nil_with_default' => false,
            'number'                     => 123,
            'boolean'                    => true,
            'multiparam'                 => nil,
            'has_default'                => "default",
            'no_valid'                   => nil
        )
      end

      it "should not clobber an existing :except option" do
        expect(@object.as_json(except: :untyped)).to eql(
            'id'                         => nil,
            'login'                      => nil,
            'can_be_nil'                 => nil,
            'can_be_nil_with_default'    => Date.today,
            'can_be_blank'               => nil,
            'can_be_blank_with_default'  => Date.today,
            'cannot_be_nil_with_default' => false,
            'number'                     => 123,
            'boolean'                    => true,
            'multiparam'                 => nil,
            'has_default'                => "default",
            'no_valid'                   => nil
        )

        expect(@object.as_json(except: [:untyped, :id])).to eql(
            'login'                      => nil,
            'can_be_nil'                 => nil,
            'can_be_nil_with_default'    => Date.today,
            'can_be_blank'               => nil,
            'can_be_blank_with_default'  => Date.today,
            'cannot_be_nil_with_default' => false,
            'number'                     => 123,
            'boolean'                    => true,
            'multiparam'                 => nil,
            'has_default'                => "default",
            'no_valid'                   => nil
        )
      end

      it "should not clobber an existing :methods option" do
        class << @object
          def foo() 1 end
          def bar() '1' end end

        expect(@object.as_json(methods: :foo)).to eql(
            'id'                         => nil,
            'login'                      => nil,
            'untyped'                    => nil,
            'can_be_nil'                 => nil,
            'can_be_nil_with_default'    => Date.today,
            'can_be_blank'               => nil,
            'can_be_blank_with_default'  => Date.today,
            'cannot_be_nil_with_default' => false,
            'number'                     => 123,
            'boolean'                    => true,
            'multiparam'                 => nil,
            'has_default'                => "default",
            'no_valid'                   => nil,
            'foo'                        => 1
        )

        expect(@object.as_json(methods: [:foo, :bar])).to eql(
            'id'                         => nil,
            'login'                      => nil,
            'untyped'                    => nil,
            'can_be_nil'                 => nil,
            'can_be_nil_with_default'    => Date.today,
            'can_be_blank'               => nil,
            'can_be_blank_with_default'  => Date.today,
            'cannot_be_nil_with_default' => false,
            'number'                     => 123,
            'boolean'                    => true,
            'multiparam'                 => nil,
            'has_default'                => "default",
            'no_valid'                   => nil,
            'foo'                        => 1,
            'bar'                        => '1'
        )
      end
    end

    describe "#to_xml" do
      before :each do
        @object         = SpecSupport::HasMetadataTester.new
        @object.number  = 123
        @object.boolean = true
      end

      it "should include metadata fields" do
        expect(@object.to_xml).to eql(<<-XML)
<?xml version="1.0" encoding="UTF-8"?>
<has-metadata-tester>
  <id type="integer" nil="true"/>
  <login nil="true"/>
  <untyped nil="true"/>
  <can-be-nil nil="true"/>
  <can-be-nil-with-default type="date">#{Date.today.to_s}</can-be-nil-with-default>
  <can-be-blank nil="true"/>
  <can-be-blank-with-default type="date">#{Date.today.to_s}</can-be-blank-with-default>
  <cannot-be-nil-with-default type="boolean">false</cannot-be-nil-with-default>
  <number type="integer">123</number>
  <boolean type="boolean">true</boolean>
  <multiparam nil="true"/>
  <has-default>default</has-default>
  <no-valid nil="true"/>
</has-metadata-tester>
        XML
      end

      it "should not clobber an existing :except option" do
        expect(@object.to_xml(except: :untyped)).to eql(<<-XML)
<?xml version="1.0" encoding="UTF-8"?>
<has-metadata-tester>
  <id type="integer" nil="true"/>
  <login nil="true"/>
  <can-be-nil nil="true"/>
  <can-be-nil-with-default type="date">#{Date.today.to_s}</can-be-nil-with-default>
  <can-be-blank nil="true"/>
  <can-be-blank-with-default type="date">#{Date.today.to_s}</can-be-blank-with-default>
  <cannot-be-nil-with-default type="boolean">false</cannot-be-nil-with-default>
  <number type="integer">123</number>
  <boolean type="boolean">true</boolean>
  <multiparam nil="true"/>
  <has-default>default</has-default>
  <no-valid nil="true"/>
</has-metadata-tester>
        XML

        expect(@object.to_xml(except: [:untyped, :id])).to eql(<<-XML)
<?xml version="1.0" encoding="UTF-8"?>
<has-metadata-tester>
  <login nil="true"/>
  <can-be-nil nil="true"/>
  <can-be-nil-with-default type="date">#{Date.today.to_s}</can-be-nil-with-default>
  <can-be-blank nil="true"/>
  <can-be-blank-with-default type="date">#{Date.today.to_s}</can-be-blank-with-default>
  <cannot-be-nil-with-default type="boolean">false</cannot-be-nil-with-default>
  <number type="integer">123</number>
  <boolean type="boolean">true</boolean>
  <multiparam nil="true"/>
  <has-default>default</has-default>
  <no-valid nil="true"/>
</has-metadata-tester>
        XML
      end

      it "should not clobber an existing :methods option" do
        class << @object
          def foo() 1 end
          def bar() '1' end
        end

        expect(@object.to_xml(methods: :foo)).to eql(<<-XML)
<?xml version="1.0" encoding="UTF-8"?>
<has-metadata-tester>
  <id type="integer" nil="true"/>
  <login nil="true"/>
  <foo type="integer">1</foo>
  <untyped nil="true"/>
  <can-be-nil nil="true"/>
  <can-be-nil-with-default type="date">#{Date.today.to_s}</can-be-nil-with-default>
  <can-be-blank nil="true"/>
  <can-be-blank-with-default type="date">#{Date.today.to_s}</can-be-blank-with-default>
  <cannot-be-nil-with-default type="boolean">false</cannot-be-nil-with-default>
  <number type="integer">123</number>
  <boolean type="boolean">true</boolean>
  <multiparam nil="true"/>
  <has-default>default</has-default>
  <no-valid nil="true"/>
</has-metadata-tester>
        XML

        expect(@object.to_xml(methods: [:foo, :bar])).to eql(<<-XML)
<?xml version="1.0" encoding="UTF-8"?>
<has-metadata-tester>
  <id type="integer" nil="true"/>
  <login nil="true"/>
  <foo type="integer">1</foo>
  <bar>1</bar>
  <untyped nil="true"/>
  <can-be-nil nil="true"/>
  <can-be-nil-with-default type="date">#{Date.today.to_s}</can-be-nil-with-default>
  <can-be-blank nil="true"/>
  <can-be-blank-with-default type="date">#{Date.today.to_s}</can-be-blank-with-default>
  <cannot-be-nil-with-default type="boolean">false</cannot-be-nil-with-default>
  <number type="integer">123</number>
  <boolean type="boolean">true</boolean>
  <multiparam nil="true"/>
  <has-default>default</has-default>
  <no-valid nil="true"/>
</has-metadata-tester>
        XML
      end
    end

    context "[dirty]" do
      before :each do
        @object = SpecSupport::HasMetadataTester.create!(untyped: 'foo', number: 123, boolean: true, multiparam: SpecSupport::ConstructorTester.new(1, 2, 3))
      end

      it "should merge local changes with changed metadata" do
        @object.login   = 'me'
        @object.untyped = 'baz'
        expect(@object.changes).to eql('login' => [nil, 'me'], 'untyped' => %w( foo baz ))
      end

      it "should clear changed metadata when saved" do
        @object.login   = 'me'
        @object.untyped = 'baz'
        @object.save!
        expect(@object.changes).to eql({})
      end

      it "should work when there is no associated metadata" do
        expect(SpecSupport::HasMetadataTester.new(login: 'hello').changes).to eql('login' => [nil, 'hello'])
      end
    end
  end
end
