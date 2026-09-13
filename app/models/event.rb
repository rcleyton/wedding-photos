class Event < ApplicationRecord
  has_secure_token :public_token

  has_many :photos, dependent: :destroy

  validates :name, presence: true
  validates :slug, :public_token, presence: true, uniqueness: true
end
