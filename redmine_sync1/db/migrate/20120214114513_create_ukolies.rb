class CreateUkolies < ActiveRecord::Migration
  def self.up
    create_table :ukolies do |t|
    end
  end

  def self.down
    drop_table :ukolies
  end
end
