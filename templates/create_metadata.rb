class CreateMetadata < ActiveRecord::Migration
  def change
    create_table :metadata do |t|
      t.text :data
    end
  end
end
