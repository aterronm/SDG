class Model < ApplicationRecord
    belongs_to :brand
    has_many :vehicles, dependent: :destroy
  end