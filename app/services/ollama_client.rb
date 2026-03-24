class OllamaClient
  BASE_URL = ENV.fetch('OLLAMA_BASE_URL', 'http://localhost:11434')
  DEFAULT_MODEL = ENV.fetch('OLLAMA_MODEL', 'qwen3.5:2b')
  TIMEOUT = ENV.fetch('OLLAMA_TIMEOUT', 300).to_i

  class RequestError < StandardError; end

  def initialize(model: DEFAULT_MODEL)
    @model = model
  end

  def generate(prompt:, images: nil)
    body = { model: @model, prompt: prompt, stream: false }
    body[:images] = Array(images).map { |img| strip_base64_prefix(img) } if images

    response = post('/api/generate', body)
    response['response']
  end

  def chat(messages:)
    formatted = messages.map do |msg|
      m = { role: msg[:role], content: msg[:content] }
      m[:images] = Array(msg[:images]) if msg[:images]
      m
    end

    body = { model: @model, messages: formatted, stream: false }

    response = post('/api/chat', body)
    response.dig('message', 'content')
  end

  private

  def strip_base64_prefix(str)
    str.sub(%r{^data:image/[^;]+;base64,}, '')
  end

  def post(path, body)
    response = HTTParty.post(
      "#{BASE_URL}#{path}",
      body: body.to_json,
      headers: { 'Content-Type' => 'application/json' },
      timeout: TIMEOUT
    )

    raise RequestError, "Ollama API error (#{response.code}): #{response.body}" unless response.success?

    response.parsed_response
  end
end
