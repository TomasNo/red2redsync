class CreateProjekts < ActiveRecord::Migration
  def self.up
    create_table :projekts do |t|
    end
  end

  def self.down
    drop_table :projekts
  end
end
