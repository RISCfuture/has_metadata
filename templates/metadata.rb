# Stores information about a model that doesn't need to be in that model's
# table. Each row in the @metadata@ table stores a schemaless, serialized hash
# of data associated with a model instance. Any model can have an associated row
# in the @metadata@ table by using the {HasMetadata} module.
#
# h2. Properties
#
# | @data@ | A hash of this metadata's contents (YAML serialized in the database). |

class Metadata < HasMetadata::Model
end
