class Wilayah < ApplicationRecord
  LEVEL_PROV = 1; LEVEL_REG = 2; LEVEL_DIS = 3; LEVEL_VIL = 4
  scope :provinsis, -> { where(level: LEVEL_PROV) }
  scope :regencies_of, ->(prov2) { where(level: LEVEL_REG, parent_code_norm: prov2) }
  scope :districts_of, ->(reg4) { where(level: LEVEL_DIS, parent_code_norm: reg4) }
end
