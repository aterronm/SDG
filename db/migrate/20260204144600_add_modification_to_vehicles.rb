class AddModificationToVehicles < ActiveRecord::Migration[7.0]
  def change
    # Para guardar: "2.0 TSI (333 Hp) 4Drive DSG"
    unless column_exists?(:vehicles, :modification_engine)
      add_column :vehicles, :modification_engine, :string
    end
  end
end