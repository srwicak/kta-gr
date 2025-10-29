# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_10_29_110002) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "kta_sequences", primary_key: "area6_code", id: :string, force: :cascade do |t|
    t.integer "last_value", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "letter_sequences", primary_key: "period", id: :string, force: :cascade do |t|
    t.integer "last_value", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "members", force: :cascade do |t|
    t.string "name", null: false
    t.string "nik", null: false
    t.string "phone", null: false
    t.string "nik_fingerprint", null: false
    t.date "birthdate"
    t.string "gender"
    t.string "area2_code"
    t.string "area4_code"
    t.string "area6_code"
    t.string "dom_area2_code"
    t.string "dom_area4_code"
    t.string "dom_area6_code"
    t.string "kta_number"
    t.string "password_digest"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "phone_fingerprint"
    t.string "dom_area10_code"
    t.text "dom_address"
    t.string "public_id"
    t.string "sk_number"
    t.integer "letter_sequence"
    t.integer "letter_month"
    t.integer "letter_year"
    t.index ["dom_area10_code"], name: "index_members_on_dom_area10_code"
    t.index ["kta_number"], name: "index_members_on_kta_number", unique: true
    t.index ["letter_year", "letter_month", "letter_sequence"], name: "idx_on_letter_year_letter_month_letter_sequence_872c4c2a5e", unique: true
    t.index ["nik"], name: "index_members_on_nik", unique: true
    t.index ["nik_fingerprint"], name: "index_members_on_nik_fingerprint", unique: true
    t.index ["phone_fingerprint"], name: "index_members_on_phone_fingerprint", unique: true
    t.index ["public_id"], name: "index_members_on_public_id", unique: true
    t.index ["sk_number"], name: "index_members_on_sk_number", unique: true
  end

  create_table "wilayahs", force: :cascade do |t|
    t.string "code_dotted", null: false
    t.string "code_norm", null: false
    t.integer "level", null: false
    t.string "name", null: false
    t.string "parent_code_norm"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code_norm"], name: "index_wilayahs_on_code_norm", unique: true
    t.index ["level", "code_norm"], name: "index_wilayahs_on_level_and_code_norm"
    t.index ["parent_code_norm"], name: "index_wilayahs_on_parent_code_norm"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
end
