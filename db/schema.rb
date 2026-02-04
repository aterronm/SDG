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

ActiveRecord::Schema[8.1].define(version: 2026_02_04_144600) do
  create_schema "extensions"

  # These are extensions that must be enabled in order to support this database
  enable_extension "extensions.pg_stat_statements"
  enable_extension "extensions.pgcrypto"
  enable_extension "extensions.uuid-ossp"
  enable_extension "graphql.pg_graphql"
  enable_extension "pg_catalog.plpgsql"
  enable_extension "vault.supabase_vault"

  create_table "public.brands", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "public.chassis_specs", force: :cascade do |t|
    t.string "assisting_systems"
    t.datetime "created_at", null: false
    t.integer "curb_weight_kg"
    t.string "drive_wheels"
    t.string "front_brakes"
    t.text "front_suspension"
    t.string "front_tyres"
    t.string "front_wheels_width"
    t.integer "fuel_tank_capacity"
    t.float "ground_clearance"
    t.integer "max_towing_weight"
    t.string "rear_axle"
    t.string "rear_brakes"
    t.text "rear_suspension"
    t.string "rear_tyres"
    t.string "rear_wheels_width"
    t.string "rims_size"
    t.string "steering_type"
    t.string "transmission"
    t.integer "trunk_capacity_l"
    t.float "turning_circle"
    t.datetime "updated_at", null: false
    t.bigint "vehicle_id", null: false
    t.index ["vehicle_id"], name: "index_chassis_specs_on_vehicle_id"
  end

  create_table "public.engine_specs", force: :cascade do |t|
    t.string "aspiration"
    t.float "battery_capacity_kwh"
    t.string "bore_stroke"
    t.boolean "catalytic_converter"
    t.string "charging_time"
    t.string "compression_ratio"
    t.float "coolant_capacity_l"
    t.datetime "created_at", null: false
    t.string "cylinders"
    t.integer "displacement_cc"
    t.integer "electric_power_ps"
    t.integer "electric_range_km"
    t.integer "electric_torque_nm"
    t.string "engine_alignment"
    t.string "engine_code"
    t.string "engine_configuration"
    t.string "engine_position"
    t.string "fast_charging_time"
    t.string "fuel_system"
    t.string "fuel_type"
    t.integer "horsepower_ps"
    t.string "lubrication"
    t.float "oil_capacity_l"
    t.float "power_per_litre_hp_l"
    t.integer "torque_nm"
    t.integer "total_system_power_ps"
    t.integer "total_system_torque_nm"
    t.datetime "updated_at", null: false
    t.integer "valves"
    t.string "valvetrain"
    t.bigint "vehicle_id", null: false
    t.index ["vehicle_id"], name: "index_engine_specs_on_vehicle_id"
  end

  create_table "public.models", force: :cascade do |t|
    t.bigint "brand_id", null: false
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
    t.index ["brand_id"], name: "index_models_on_brand_id"
  end

  create_table "public.performance_stats", force: :cascade do |t|
    t.float "acceleration_0_100"
    t.float "acceleration_0_60_mph"
    t.integer "co2_emissions"
    t.datetime "created_at", null: false
    t.float "drag_coefficient"
    t.string "emission_standard"
    t.float "fuel_consumption_extra_urban"
    t.float "fuel_consumption_urban"
    t.float "fuel_consumption_wltp"
    t.integer "range_wltp"
    t.integer "top_speed_kmh"
    t.datetime "updated_at", null: false
    t.bigint "vehicle_id", null: false
    t.float "weight_power_ratio"
    t.index ["vehicle_id"], name: "index_performance_stats_on_vehicle_id"
  end

  create_table "public.vehicles", force: :cascade do |t|
    t.string "body_type"
    t.datetime "created_at", null: false
    t.integer "doors"
    t.float "front_overhang_cm"
    t.float "front_track_cm"
    t.string "generation"
    t.float "ground_clearance_cm"
    t.float "height_cm"
    t.float "length_cm"
    t.integer "max_load_kg"
    t.integer "max_towing_weight_kg"
    t.integer "max_weight_kg"
    t.bigint "model_id", null: false
    t.string "modification_engine"
    t.string "name"
    t.string "powertrain_architecture"
    t.integer "production_end_year"
    t.integer "production_start_year"
    t.float "rear_overhang_cm"
    t.float "rear_track_cm"
    t.integer "seats"
    t.integer "trunk_capacity_max_l"
    t.float "turning_circle_m"
    t.datetime "updated_at", null: false
    t.float "wheelbase_cm"
    t.float "width_cm"
    t.float "width_with_mirrors_cm"
    t.index ["model_id"], name: "index_vehicles_on_model_id"
  end

  add_foreign_key "public.chassis_specs", "public.vehicles"
  add_foreign_key "public.engine_specs", "public.vehicles"
  add_foreign_key "public.models", "public.brands"
  add_foreign_key "public.performance_stats", "public.vehicles"
  add_foreign_key "public.vehicles", "public.models"

end
