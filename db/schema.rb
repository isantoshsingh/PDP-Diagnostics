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

ActiveRecord::Schema[8.1].define(version: 2026_01_30_144121) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "alerts", force: :cascade do |t|
    t.string "alert_type", null: false
    t.datetime "created_at", null: false
    t.string "delivery_status", default: "pending", null: false
    t.bigint "issue_id", null: false
    t.datetime "sent_at"
    t.bigint "shop_id", null: false
    t.datetime "updated_at", null: false
    t.index ["alert_type"], name: "index_alerts_on_alert_type"
    t.index ["delivery_status"], name: "index_alerts_on_delivery_status"
    t.index ["issue_id"], name: "index_alerts_on_issue_id"
    t.index ["shop_id", "issue_id"], name: "index_alerts_on_shop_id_and_issue_id", unique: true
    t.index ["shop_id"], name: "index_alerts_on_shop_id"
  end

  create_table "issues", force: :cascade do |t|
    t.datetime "acknowledged_at"
    t.string "acknowledged_by"
    t.datetime "created_at", null: false
    t.text "description"
    t.text "evidence"
    t.datetime "first_detected_at", null: false
    t.string "issue_type", null: false
    t.datetime "last_detected_at", null: false
    t.integer "occurrence_count", default: 1, null: false
    t.bigint "product_page_id", null: false
    t.bigint "scan_id", null: false
    t.string "severity", null: false
    t.string "status", default: "open", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["product_page_id", "issue_type", "status"], name: "index_issues_on_product_page_id_and_issue_type_and_status"
    t.index ["product_page_id", "status"], name: "index_issues_on_product_page_id_and_status"
    t.index ["product_page_id"], name: "index_issues_on_product_page_id"
    t.index ["scan_id"], name: "index_issues_on_scan_id"
    t.index ["severity"], name: "index_issues_on_severity"
    t.index ["status"], name: "index_issues_on_status"
  end

  create_table "product_pages", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "handle", null: false
    t.datetime "last_scanned_at"
    t.boolean "monitoring_enabled", default: true, null: false
    t.bigint "shop_id", null: false
    t.bigint "shopify_product_id", null: false
    t.string "status", default: "pending", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.string "url", null: false
    t.index ["shop_id", "monitoring_enabled"], name: "index_product_pages_on_shop_id_and_monitoring_enabled"
    t.index ["shop_id", "shopify_product_id"], name: "index_product_pages_on_shop_id_and_shopify_product_id", unique: true
    t.index ["shop_id"], name: "index_product_pages_on_shop_id"
    t.index ["status"], name: "index_product_pages_on_status"
  end

  create_table "scans", force: :cascade do |t|
    t.datetime "completed_at"
    t.text "console_logs"
    t.datetime "created_at", null: false
    t.text "error_message"
    t.text "html_snapshot"
    t.text "js_errors"
    t.text "network_errors"
    t.integer "page_load_time_ms"
    t.bigint "product_page_id", null: false
    t.string "screenshot_url"
    t.datetime "started_at"
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["product_page_id", "created_at"], name: "index_scans_on_product_page_id_and_created_at"
    t.index ["product_page_id"], name: "index_scans_on_product_page_id"
    t.index ["started_at"], name: "index_scans_on_started_at"
    t.index ["status"], name: "index_scans_on_status"
  end

  create_table "shop_settings", force: :cascade do |t|
    t.boolean "admin_alerts_enabled", default: true, null: false
    t.string "alert_email"
    t.string "billing_status", default: "trial", null: false
    t.datetime "created_at", null: false
    t.boolean "email_alerts_enabled", default: true, null: false
    t.integer "max_monitored_pages", default: 5, null: false
    t.string "scan_frequency", default: "daily", null: false
    t.bigint "shop_id", null: false
    t.bigint "subscription_charge_id"
    t.datetime "trial_ends_at"
    t.datetime "updated_at", null: false
    t.index ["billing_status"], name: "index_shop_settings_on_billing_status"
    t.index ["shop_id"], name: "index_shop_settings_on_shop_id", unique: true
  end

  create_table "shops", force: :cascade do |t|
    t.string "access_scopes", default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.string "refresh_token"
    t.datetime "refresh_token_expires_at"
    t.string "shopify_domain", null: false
    t.string "shopify_token", null: false
    t.datetime "updated_at", null: false
    t.index ["shopify_domain"], name: "index_shops_on_shopify_domain", unique: true
  end

  add_foreign_key "alerts", "issues"
  add_foreign_key "alerts", "shops"
  add_foreign_key "issues", "product_pages"
  add_foreign_key "issues", "scans"
  add_foreign_key "product_pages", "shops"
  add_foreign_key "scans", "product_pages"
  add_foreign_key "shop_settings", "shops"
end
