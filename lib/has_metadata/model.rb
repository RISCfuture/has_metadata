module HasMetadata
  
  # Base class of the {Metadata} model. Functionality is moved to this class to
  # make changes to the model easier. See the @Metadata@ method for more
  # information.
  
  class Model < ActiveRecord::Base
    self.table_name = 'metadata'
    serialize :data, Hash

    after_initialize :initialize_data
    before_save :nullify_empty_fields

    # @private
    def set_fields(fields)
      return self if @_fields_set
      @_fields_set = true
      
      singleton_class.send(:define_method, :attribute_method?) do |name|
        name = name.to_sym
        super(name) or fields.include?(name)
      end
      
      # override attribute prefix/suffix methods to get full first-class
      # property functionality
      
      singleton_class.send(:define_method, :attribute) do |name|
        name = name.to_sym
        super(name) unless fields.include?(name)

        options = fields[name] || {}
        default = options.include?(:default) ? options[:default] : nil
        data.include?(name) ? data[name] : default
      end
      singleton_class.send :alias_method, :attribute_before_type_cast, :attribute
      
      singleton_class.send(:define_method, :query_attribute) do |name|
        name = name.to_sym
        super(name) unless fields.include?(name)

        options = fields[name] || {}
        if options.include?(:type) then
          if options[:type].ancestors.include?(Numeric) then
            not send(name).zero?
          else
            not send(name).blank?
          end
        else
          not send(name).blank?
        end
      end
      
      singleton_class.send(:define_method, :attribute=) do |name, value|
        name = name.to_sym
        super(name, value) unless fields.include?(name)

        options = fields[name] || {}
        data_will_change!
        data[name] = HasMetadata.metadata_typecast(value, options[:type])
      end

      self
    end

    private

    def initialize_data
      self.data ||= Hash.new
    end

    def nullify_empty_fields
      data.each { |key, value| data[key] = nil if value == "" }
    end
  end
end
