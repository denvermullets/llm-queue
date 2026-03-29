class SbcJob < ApplicationJob
  queue_as :sbc

  def perform(llm_request_id)
    llm_request = LlmRequest.find(llm_request_id)
    llm_request.update!(status: 'processing')

    result = process_image(llm_request, llm_request_id)
    parsed = LlmRequest.parse_llm_result(result)
    llm_request.update!(status: 'completed', response: { result: parsed })
    WebhookDeliveryService.new(llm_request).deliver
  rescue StandardError => e
    llm_request&.update(status: 'failed', response: { error: e.message })
    WebhookDeliveryService.new(llm_request).deliver if llm_request&.callback_url.present?
    raise
  end

  private

  def process_image(llm_request, llm_request_id)
    ocr_text = extract_text(llm_request)
    Rails.logger.info("SbcJob##{llm_request_id} OCR extracted #{ocr_text.length} chars: #{ocr_text.truncate(500)}")

    prompt = build_prompt(llm_request, ocr_text)
    result = OllamaClient.new.generate(prompt: prompt)
    Rails.logger.info("SbcJob##{llm_request_id} LLM result #{result.length} chars: #{result.truncate(500)}")
    result
  end

  def extract_text(llm_request)
    images = llm_request.payload.fetch('images', [])
    images.map { |img| OcrService.new(img).extract_text }.join("\n\n")
  end

  def build_prompt(llm_request, ocr_text)
    user_prompt = llm_request.payload.fetch('prompt', 'Extract all data from this text.')
    "#{user_prompt}\n\nExtracted text from image:\n#{ocr_text}"
  end
end
