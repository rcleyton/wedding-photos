class Photo < ApplicationRecord
  ALLOWED_CONTENT_TYPES = %w[
    image/jpeg
    image/png
    image/webp
    image/heic
    image/heif
  ].freeze

  MAX_FILE_SIZE = 20.megabytes

  belongs_to :event

  has_one_attached :file

  enum :status, {
    pending: 0,
    uploaded: 1,
    failed: 2
  }, default: :pending

  validates :file, presence: true

  validate :acceptable_file_type
  validate :acceptable_file_size

  private

  def acceptable_file_type
    return unless file.attached?

    unless ALLOWED_CONTENT_TYPES.include?(file.blob.content_type)
      errors.add(
        :file,
        "deve ser uma imagem JPEG, PNG, WebP, HEIC ou HEIF."
      )
    end
  end

  def acceptable_file_size
    return unless file.attached?

    if file.blob.byte_size > MAX_FILE_SIZE
      errors.add(
        :file,
        "deve ter no máximo 20 MB."
      )
    end
  end
end
