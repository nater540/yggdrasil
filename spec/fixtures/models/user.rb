class User < BaseRecord
  has_secure_password

  has_many :posts

  has_many :users_tags
  has_many :tags, through: :users_tags

  validates :first_name, :last_name, :email, presence: true
end
