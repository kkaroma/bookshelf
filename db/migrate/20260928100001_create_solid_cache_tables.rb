# Tables for Solid Cache (Rails.cache in production), kept in the main database.
# Copied from the db/cache_schema.rb that Rails generated for a separate database;
# with PostgreSQL on Fly.io we use one database for everything.
class CreateSolidCacheTables < ActiveRecord::Migration[8.1]
  def change
    create_table "solid_cache_entries" do |t|
      t.binary "key", limit: 1024, null: false
      t.binary "value", limit: 536870912, null: false
      t.datetime "created_at", null: false
      t.integer "key_hash", limit: 8, null: false
      t.integer "byte_size", limit: 4, null: false
      t.index [ "byte_size" ], name: "index_solid_cache_entries_on_byte_size"
      t.index [ "key_hash", "byte_size" ], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
      t.index [ "key_hash" ], name: "index_solid_cache_entries_on_key_hash", unique: true
    end
  end
end
