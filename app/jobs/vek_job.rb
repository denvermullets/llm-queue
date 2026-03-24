class VekJob < ApplicationJob
  queue_as :vek

  def perform(llm_request_id)
    llm_request = LlmRequest.find(llm_request_id)
    llm_request.update!(status: 'processing')

    # TODO: Send text payload to local LLM and store response
    # response = LlmClient.text_request(llm_request.payload)
    # llm_request.update!(status: "completed", response: response)
  rescue StandardError => e
    llm_request&.update(status: 'failed', response: { error: e.message })
    raise
  end
end
