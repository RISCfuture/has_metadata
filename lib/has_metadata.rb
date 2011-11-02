require 'has_metadata/metadata_generator'
require 'has_metadata/model'
require 'boolean'

# @private
class Object

  # Creates a deep copy of this object.
  #
  # @raise [TypeError] If the object cannot be deep-copied. All objects that can
  #   be marshalled can be deep-copied.

  def deep_clone
    Marshal.load Marshal.dump(self)
  end
end


# Provides the {ClassMethods#has_metadata} method to subclasses of @ActiveRecord::Base@.

module HasMetadata
  extend ActiveSupport::Concern
  
  # @private
  def self.metadata_typecast(value, type)
    if value.kind_of?(String) then
      if type == Integer or type == Fixnum then
        begin
          return Integer(value)
        rescue ArgumentError
          return value
        end
      elsif type == Float then
        begin
          return Float(value)
        rescue ArgumentError
          return value
        end
      elsif type == Boolean then return value.parse_bool end
    end
    return value
  end
  
  # Class methods that are added to your model.
  
  module ClassMethods

    # Defines a set of fields whose values exist in the associated {Metadata}
    # record. Each key in the @fields@ hash is the name of a metadata field, and
    # the value is a set of options to pass to the @validates@ method. If you do
    # not want to perform any validation on a field, simply pass @true@ as its
    # key value.
    #
    # In addition to the normal @validates@ keys, you can also include a @:type@
    # key to restrict values to certain classes, or a @:default@ key to specify
    # a value to return for the getter should none be set (normal default is
    # @nil@).
    #
    # @param [Hash<Symbol, Hash>] fields A mapping of field names to their
    #   validation options (and/or the @:type@ key).
    #
    # @example Three metadata fields, one basic, one validated, and one type-checked.
    #   has_metadata(optional: true, required: { presence: true }, number: { type: Fixnum })

    def has_metadata(fields)
      if !respond_to?(:metadata_fields) then
        belongs_to :metadata, dependent: :destroy
        accepts_nested_attributes_for :metadata
        after_save :save_metadata, if: :metadata_changed?

        class_attribute :metadata_fields
        self.metadata_fields = fields.deep_clone

        define_method(:save_metadata) { metadata.save! }
        define_method(:metadata_changed?) { metadata.try :changed? }
      else
        raise "Cannot redefine existing metadata fields: #{(fields.keys & self.metadata_fields.keys).to_sentence}" unless (fields.keys & self.metadata_fields.keys).empty?
        self.metadata_fields = self.metadata_fields.merge(fields)
      end

      fields.each do |name, options|
        # delegate all attribute methods to the metadata
        attribute_method_matchers.each { |matcher| delegate matcher.method_name(name), to: :metadata! }
        
        if options.kind_of?(Hash) then
          type = options.delete(:type)
          options.delete :default
          
          validate do |obj|
            value = obj.send(name)
            errors.add(name, :incorrect_type) unless
              HasMetadata.metadata_typecast(value, type).kind_of?(type) or
                ((options[:allow_nil] and value.nil?) or (options[:allow_blank] and value.blank?))
          end if type
          validates(name, options) unless options.empty? or (options.keys - [ :allow_nil, :allow_blank ]).empty?
        end
      end
    end
  end

  # Instance methods that are added to your model.

  module InstanceMethods

    def as_json(options={})
      options[:except] = Array.wrap(options[:except]) + [ :metadata_id ]
      options[:methods] = Array.wrap(options[:methods]) + metadata_fields.keys - options[:except].map(&:to_sym)
      super options
    end
    
    def to_xml(options={})
      options[:except] = Array.wrap(options[:except]) + [ :metadata_id ]
      options[:methods] = Array.wrap(options[:methods]) + metadata_fields.keys - options[:except].map(&:to_sym)
      super options
    end

    # @private
    def assign_multiparameter_attributes(pairs)
      fake_attributes = pairs.select { |(field, _)| self.class.metadata_fields.include? field[0, field.index('(')].to_sym }

      fake_attributes.group_by { |(field, _)| field[0, field.index('(')] }.each do |field_name, parts|
        options = self.class.metadata_fields[field_name.to_sym]
        if options[:type] then
          args = parts.each_with_object([]) do |(part_name, value), ary|
            part_ann = part_name[part_name.index('(') + 1, part_name.length]
            index = part_ann.to_i - 1
            raise "Out-of-bounds multiparameter argument index" unless index >= 0
            ary[index] = if value.blank? then nil
              elsif part_ann.ends_with?('i)') then value.to_i
              elsif part_ann.ends_with?('f)') then value.to_f
              else value end
          end
          args.compact!
          send :"#{field_name}=", options[:type].new(*args) unless args.empty?
        else
          raise "#{field_name} has no type and cannot be used for multiparameter assignment"
        end
      end

      super(pairs - fake_attributes)
    end

    # @return [Metadata] An existing associated {Metadata} instance, or new,
    #   saved one if none was found.

    def metadata!
      if instance_variables.include?(:@metadata) then
        metadata.set_fields self.class.metadata_fields
      else
        (metadata || Metadata.transaction { metadata || create_metadata }).set_fields self.class.metadata_fields
      end
    end

    # @private
    def inspect
      "#<#{self.class.to_s} #{attributes.merge(metadata.try(:data).try(:stringify_keys) || {}).map { |k,v| "#{k}: #{v.inspect}" }.join(', ')}>"
    end
  end
end
