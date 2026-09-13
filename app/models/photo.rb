class Photo < ApplicationRecord
  belongs_to :event

  has_one_attached :file

  enum :status, { pending: 0, uploaded: 1, failed: 2 }, default: :pending

  validates :file, presence: true
end
