class Vehicle < ApplicationRecord
    belongs_to :model # <--- Cambio clave: Ahora pertenece a un modelo, no a una marca directa
    has_one :engine_spec, dependent: :destroy
    has_one :performance_stat, dependent: :destroy
    has_one :chassis_spec, dependent: :destroy
  end