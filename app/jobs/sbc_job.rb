class SbcJob < ApplicationJob
  queue_as :sbc

  def perform(llm_request_id)
    llm_request = LlmRequest.find(llm_request_id)
    llm_request.update!(status: 'processing')

    client = OllamaClient.new
    result = client.generate(
      prompt: llm_request.payload.fetch('prompt', 'Describe this image'),
      images: llm_request.payload['images']
    )

    parsed = LlmRequest.parse_llm_result(result)
    llm_request.update!(status: 'completed', response: { result: parsed })
    WebhookDeliveryService.new(llm_request).deliver
  rescue StandardError => e
    llm_request&.update(status: 'failed', response: { error: e.message })
    WebhookDeliveryService.new(llm_request).deliver if llm_request&.callback_url.present?
    raise
  end
end
