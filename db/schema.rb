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

ActiveRecord::Schema[8.1].define(version: 2026_03_28_132006) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "llm_requests", force: :cascade do |t|
    t.string "callback_url"
    t.datetime "created_at", null: false
    t.string "external_id"
    t.jsonb "payload", default: {}, null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.string "request_type", null: false
    t.jsonb "response"
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.jsonb "webhook_payload"
    t.datetime "webhook_sent_at"
    t.string "webhook_status"
    t.index ["priority", "created_at"], name: "index_llm_requests_on_priority_and_created_at"
    t.index ["queue_name"], name: "index_llm_requests_on_queue_name"
    t.index ["status"], name: "index_llm_requests_on_status"
  end
end
