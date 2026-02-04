class AddAutoDataSpecsToVehicles < ActiveRecord::Migration[7.0]
  def change
    # --- 1. VEHÍCULO Y DIMENSIONES DETALLADAS (Tabla Vehicles) ---
    #
    add_column :vehicles, :powertrain_architecture, :string unless column_exists?(:vehicles, :powertrain_architecture)
    add_column :vehicles, :width_with_mirrors_cm, :float unless column_exists?(:vehicles, :width_with_mirrors_cm)
    add_column :vehicles, :front_track_cm, :float unless column_exists?(:vehicles, :front_track_cm)
    add_column :vehicles, :rear_track_cm, :float unless column_exists?(:vehicles, :rear_track_cm)
    add_column :vehicles, :front_overhang_cm, :float unless column_exists?(:vehicles, :front_overhang_cm)
    add_column :vehicles, :rear_overhang_cm, :float unless column_exists?(:vehicles, :rear_overhang_cm)
    add_column :vehicles, :max_weight_kg, :integer unless column_exists?(:vehicles, :max_weight_kg)
    add_column :vehicles, :max_load_kg, :integer unless column_exists?(:vehicles, :max_load_kg)
    add_column :vehicles, :trunk_capacity_max_l, :integer unless column_exists?(:vehicles, :trunk_capacity_max_l)

    # --- 2. MOTOR TÉCNICO (Tabla EngineSpecs) ---
    #
    add_column :engine_specs, :power_per_litre_hp_l, :float unless column_exists?(:engine_specs, :power_per_litre_hp_l)
    add_column :engine_specs, :valvetrain, :string unless column_exists?(:engine_specs, :valvetrain) # DOHC, OHC...
    add_column :engine_specs, :oil_capacity_l, :float unless column_exists?(:engine_specs, :oil_capacity_l)
    add_column :engine_specs, :coolant_capacity_l, :float unless column_exists?(:engine_specs, :coolant_capacity_l)

    # --- 3. RENDIMIENTO DETALLADO (Tabla PerformanceStats) ---
    #
    add_column :performance_stats, :acceleration_0_60_mph, :float unless column_exists?(:performance_stats, :acceleration_0_60_mph)
    add_column :performance_stats, :fuel_consumption_urban, :float unless column_exists?(:performance_stats, :fuel_consumption_urban)
    add_column :performance_stats, :fuel_consumption_extra_urban, :float unless column_exists?(:performance_stats, :fuel_consumption_extra_urban)

    # --- 4. CHASIS Y EQUIPAMIENTO (Tabla ChassisSpecs) ---
    #
    add_column :chassis_specs, :rims_size, :string unless column_exists?(:chassis_specs, :rims_size)
    add_column :chassis_specs, :steering_type, :string unless column_exists?(:chassis_specs, :steering_type)
    add_column :chassis_specs, :assisting_systems, :string unless column_exists?(:chassis_specs, :assisting_systems) # ABS, etc.
  end
end