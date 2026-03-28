class LlmRequest < ApplicationRecord
  QUEUES = %w[vek sbc waxc ninetynine].freeze
  PRIORITIES = { 'vek' => 1, 'sbc' => 2, 'waxc' => 3, 'ninetynine' => 4 }.freeze
  REQUEST_TYPES = %w[text image].freeze
  STATUSES = %w[pending processing completed failed].freeze

  validates :queue_name, presence: true, inclusion: { in: QUEUES }
  validates :request_type, presence: true, inclusion: { in: REQUEST_TYPES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :priority, presence: true

  before_validation :set_priority, on: :create

  scope :pending, -> { where(status: 'pending') }
  scope :by_priority, -> { order(priority: :asc, created_at: :asc) }

  def self.parse_llm_result(result)
    return result unless result.is_a?(String)

    JSON.parse(strip_code_fences(result))
  rescue JSON::ParserError
    result
  end

  def self.strip_code_fences(text)
    text.gsub(/\A\s*```\w*\n?/, '').gsub(/\n?```\s*\z/, '')
  end

  private

  def set_priority
    self.priority = PRIORITIES.fetch(queue_name, 99) if queue_name.present?
  end
end
