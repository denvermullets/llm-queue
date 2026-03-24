class VekJob < ApplicationJob
  queue_as :vek

  def perform(llm_request_id)
    llm_request = LlmRequest.find(llm_request_id)
    llm_request.update!(status: 'processing')

    client = OllamaClient.new
    result = client.generate(prompt: llm_request.payload['prompt'])

    llm_request.update!(status: 'completed', response: { result: result })
  rescue StandardError => e
    llm_request&.update(status: 'failed', response: { error: e.message })
    raise
  end
end
