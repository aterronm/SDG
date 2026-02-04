class AddFullSpecsToVehicles < ActiveRecord::Migration[7.0]
  def change
    # --- DIMENSIONES (Tabla Vehicles) ---
    # Solo añade la columna si NO existe ya
    add_column :vehicles, :wheelbase_cm, :float unless column_exists?(:vehicles, :wheelbase_cm)
    add_column :vehicles, :length_cm, :float unless column_exists?(:vehicles, :length_cm)
    add_column :vehicles, :width_cm, :float unless column_exists?(:vehicles, :width_cm)
    add_column :vehicles, :height_cm, :float unless column_exists?(:vehicles, :height_cm)
    add_column :vehicles, :ground_clearance_cm, :float unless column_exists?(:vehicles, :ground_clearance_cm)
    add_column :vehicles, :max_towing_weight_kg, :integer unless column_exists?(:vehicles, :max_towing_weight_kg)
    add_column :vehicles, :turning_circle_m, :float unless column_exists?(:vehicles, :turning_circle_m)

    # --- MOTOR DETALLADO & ELÉCTRICO (Tabla EngineSpecs) ---
    add_column :engine_specs, :bore_stroke, :string unless column_exists?(:engine_specs, :bore_stroke)
    add_column :engine_specs, :valves, :string unless column_exists?(:engine_specs, :valves)
    add_column :engine_specs, :fuel_system, :string unless column_exists?(:engine_specs, :fuel_system)
    add_column :engine_specs, :engine_alignment, :string unless column_exists?(:engine_specs, :engine_alignment)
    add_column :engine_specs, :engine_position, :string unless column_exists?(:engine_specs, :engine_position)
    add_column :engine_specs, :engine_configuration, :string unless column_exists?(:engine_specs, :engine_configuration)
    
    # Híbrido / Eléctrico
    add_column :engine_specs, :total_system_power_ps, :integer unless column_exists?(:engine_specs, :total_system_power_ps)
    add_column :engine_specs, :total_system_torque_nm, :integer unless column_exists?(:engine_specs, :total_system_torque_nm)
    add_column :engine_specs, :electric_power_ps, :integer unless column_exists?(:engine_specs, :electric_power_ps)
    add_column :engine_specs, :electric_torque_nm, :integer unless column_exists?(:engine_specs, :electric_torque_nm)
    add_column :engine_specs, :battery_capacity_kwh, :float unless column_exists?(:engine_specs, :battery_capacity_kwh)
    add_column :engine_specs, :electric_range_km, :integer unless column_exists?(:engine_specs, :electric_range_km)
    add_column :engine_specs, :charging_time, :string unless column_exists?(:engine_specs, :charging_time)
    add_column :engine_specs, :fast_charging_time, :string unless column_exists?(:engine_specs, :fast_charging_time)

    # --- CHASIS DETALLADO (Tabla ChassisSpecs) ---
    add_column :chassis_specs, :front_suspension, :string unless column_exists?(:chassis_specs, :front_suspension)
    add_column :chassis_specs, :rear_suspension, :string unless column_exists?(:chassis_specs, :rear_suspension)
  end
end