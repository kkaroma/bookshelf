# Tables for Solid Cable (Action Cable in production), kept in the main database.
# Copied from the db/cable_schema.rb that Rails generated for a separate database;
# with PostgreSQL on Fly.io we use one database for everything.
class CreateSolidCableTables < ActiveRecord::Migration[8.1]
  def change
    create_table "solid_cable_messages" do |t|
      t.binary "channel", limit: 1024, null: false
      t.binary "payload", limit: 536870912, null: false
      t.datetime "created_at", null: false
      t.integer "channel_hash", limit: 8, null: false
      t.index [ "channel_hash" ], name: "index_solid_cable_messages_on_channel_hash"
      t.index [ "created_at" ], name: "index_solid_cable_messages_on_created_at"
    end
  end
end
