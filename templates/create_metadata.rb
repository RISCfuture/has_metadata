class CreateMetadata < ActiveRecord::Migration
  def self.up
    create_table :metadata do |t|
      t.text :data
    end
  end

  def self.down
    drop_table :metadatas
  end
end
