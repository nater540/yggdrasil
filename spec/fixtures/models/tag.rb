class Tag < BaseRecord
  has_many :users_tags
  has_many :users, through: :users_tags
end
