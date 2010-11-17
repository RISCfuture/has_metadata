module HasMetadata
  
  # Base class of the {Metadata} model. Functionality is moved to this class to
  # make changes to the model easier. See the @Metadata@ method for more
  # information.
  
  class Model < ActiveRecord::Base
    set_table_name 'metadata'
    serialize :data, Hash

    after_initialize :initialize_data
    before_save :nullify_empty_fields

    validates :data,
              presence: true

    # @private
    def set_fields(fields)
      return self if @fields_set
      @fields_set = true

      fields.each do |name, _|
        singleton_class.send(:define_method, name) { |default=nil| data.include?(name) ? data[name] : default }
        singleton_class.send(:define_method, :"#{name}=") { |value| data[name] = value }
      end

      self
    end

    private

    def initialize_data
      self.data ||= Hash.new
    end

    def nullify_empty_fields
      data.each { |key, value| data[key] = nil if data[key].blank? }
    end
  end
end