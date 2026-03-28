class WebhookDeliveryService
  MAX_RETRIES = 3
  RETRY_DELAY = 2 # seconds

  class DeliveryError < StandardError; end

  def initialize(llm_request)
    @llm_request = llm_request
  end

  def deliver
    return unless @llm_request.callback_url.present?

    @llm_request.update!(webhook_status: 'pending', webhook_payload: payload)
    attempt_delivery
  end

  private

  def attempt_delivery
    attempt = 0
    begin
      attempt += 1
      post_webhook
      mark_delivered
    rescue StandardError => e
      if attempt < MAX_RETRIES
        sleep(RETRY_DELAY * attempt)
        retry
      end
      mark_failed(e)
    end
  end

  def post_webhook
    response = HTTParty.post(
      @llm_request.callback_url,
      body: payload.to_json,
      headers: { 'Content-Type' => 'application/json' },
      timeout: 30
    )

    raise DeliveryError, "Webhook failed (#{response.code}): #{response.body}" unless response.success?
  end

  def mark_delivered
    @llm_request.update!(webhook_status: 'delivered', webhook_sent_at: Time.current)
    Rails.logger.info("Webhook delivered to #{@llm_request.callback_url} for request #{@llm_request.id}")
  end

  def mark_failed(error)
    @llm_request.update!(webhook_status: 'failed')
    Rails.logger.error("Webhook delivery failed after #{MAX_RETRIES} attempts: #{error.message}")
  end

  def payload
    @payload ||= {
      external_id: @llm_request.external_id,
      status: @llm_request.status,
      response: @llm_request.response,
      completed_at: @llm_request.updated_at.iso8601
    }
  end
end
