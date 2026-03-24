class WaxcJob < ApplicationJob
  queue_as :waxc

  def perform(llm_request_id)
    llm_request = LlmRequest.find(llm_request_id)
    llm_request.update!(status: 'processing')

    # TODO: Send image payload to local LLM and store response
    # response = LlmClient.image_request(llm_request.payload)
    # llm_request.update!(status: "completed", response: response)
  rescue StandardError => e
    llm_request&.update(status: 'failed', response: { error: e.message })
    raise
  end
end
