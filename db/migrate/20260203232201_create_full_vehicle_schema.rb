class CreateFullVehicleSchema < ActiveRecord::Migration[7.0]
  def change
    # 1. Tabla Principal: Identidad del Vehículo
    create_table :vehicles do |t|
      t.integer :brand_id, index: true
      t.integer :model_id, index: true
      t.string :name
      t.string :generation
      t.integer :production_start_year
      t.integer :production_end_year
      t.string :body_type
      t.integer :doors
      t.integer :seats
      t.timestamps
    end

    # 2. Especificaciones de Motor (El Corazón)
    create_table :engine_specs do |t|
      t.references :vehicle, null: false, foreign_key: true
      t.string :engine_code
      t.string :cylinders
      t.string :fuel_type
      t.string :fuel_system
      t.string :lubrication
      t.string :engine_alignment
      t.string :engine_position
      t.integer :displacement_cc
      t.string :bore_stroke
      t.integer :valves
      t.string :aspiration
      t.string :compression_ratio
      t.integer :horsepower_ps
      t.integer :torque_nm
      t.boolean :catalytic_converter
      t.timestamps
    end

    # 3. Rendimiento y Consumo (Dinámica)
    create_table :performance_stats do |t|
      t.references :vehicle, null: false, foreign_key: true
      t.integer :top_speed_kmh
      t.float :acceleration_0_100
      t.float :fuel_consumption_wltp
      t.integer :range_wltp
      t.integer :co2_emissions
      t.string :emission_standard
      t.float :drag_coefficient
      t.float :weight_power_ratio
      t.timestamps
    end

    # 4. Chasis y Dimensiones (Estructura)
    create_table :chassis_specs do |t|
      t.references :vehicle, null: false, foreign_key: true
      t.string :drive_wheels
      t.string :transmission
      t.integer :fuel_tank_capacity
      t.integer :curb_weight_kg
      t.integer :max_towing_weight
      t.integer :trunk_capacity_l
      t.string :front_brakes
      t.string :rear_brakes
      t.string :front_tyres
      t.string :rear_tyres
      t.string :front_wheels_width
      t.string :rear_wheels_width
      t.float :turning_circle
      t.text :front_suspension
      t.text :rear_suspension
      t.string :rear_axle
      t.float :ground_clearance
      t.timestamps
    end
  end
end