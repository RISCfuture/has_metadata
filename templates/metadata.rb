# Stores information about a model that doesn't need to be in that model's
# table. Each row in the @metadata@ table stores a schemaless, serialized hash
# of data associated with a model instance. Any model can have an associated row
# in the @metadata@ table by using the {HasMetadata} module.
#
# h2. Properties
#
# | @data@ | A hash of this metadata's contents (YAML serialized in the database). |

class Metadata < ActiveRecord::Base
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
      singleton_class.send(:define_method, name) { data[name] }
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
