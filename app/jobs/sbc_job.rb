class SbcJob < ApplicationJob
  queue_as :sbc

  def perform(llm_request_id)
    llm_request = LlmRequest.find(llm_request_id)
    llm_request.update!(status: 'processing')

    ocr_text = extract_text(llm_request)
    prompt = build_prompt(llm_request, ocr_text)

    client = OllamaClient.new
    result = client.generate(prompt: prompt)

    parsed = LlmRequest.parse_llm_result(result)
    llm_request.update!(status: 'completed', response: { result: parsed })
    WebhookDeliveryService.new(llm_request).deliver
  rescue StandardError => e
    llm_request&.update(status: 'failed', response: { error: e.message })
    WebhookDeliveryService.new(llm_request).deliver if llm_request&.callback_url.present?
    raise
  end

  private

  def extract_text(llm_request)
    images = llm_request.payload.fetch('images', [])
    images.map { |img| OcrService.new(img).extract_text }.join("\n\n")
  end

  def build_prompt(llm_request, ocr_text)
    user_prompt = llm_request.payload.fetch('prompt', 'Extract all data from this text.')
    "#{user_prompt}\n\nExtracted text from image:\n#{ocr_text}"
  end
end
