class AddBrandsAndModels < ActiveRecord::Migration[7.0]
  def change
    # 1. Tabla de Marcas (Ej: BMW)
    create_table :brands do |t|
      t.string :name
      t.timestamps
    end

    # 2. Tabla de Modelos/Familias (Ej: iX 2026, Serie 3 E46)
    create_table :models do |t|
      t.string :name
      t.references :brand, null: false, foreign_key: true
      t.timestamps
    end

    # 3. Actualizamos la tabla Vehicles para que pertenezca a un Modelo real
    # Primero eliminamos los campos antiguos si molestan, o simplemente añadimos la FK
    # Asumimos que tenías model_id como integer simple, ahora lo hacemos Foreign Key real
    remove_column :vehicles, :model_id, :integer if column_exists?(:vehicles, :model_id)
    remove_column :vehicles, :brand_id, :integer if column_exists?(:vehicles, :brand_id)
    
    add_reference :vehicles, :model, null: false, foreign_key: true
  end
end