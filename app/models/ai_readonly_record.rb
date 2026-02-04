class AiReadonlyRecord < ApplicationRecord
  # Esto indica que es una clase abstracta (no tiene tabla propia)
  self.abstract_class = true
  
  # Aquí ocurre la magia: conecta usando la configuración 'ai_readonly' del database.yml
  connects_to database: { writing: :ai_readonly, reading: :ai_readonly }
end