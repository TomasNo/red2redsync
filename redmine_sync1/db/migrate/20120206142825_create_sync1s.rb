class CreateSync1s < ActiveRecord::Migration
  def self.up
    create_table :sync1s do |t|
    end
  end

  def self.down
    drop_table :sync1s
  end
end
