class OllamaClient
  BASE_URL = ENV.fetch('OLLAMA_BASE_URL', 'http://localhost:11434')
  DEFAULT_MODEL = ENV.fetch('OLLAMA_MODEL', 'qwen3.5:0.8b')
  TIMEOUT = ENV.fetch('OLLAMA_TIMEOUT', 300).to_i

  class RequestError < StandardError; end

  def initialize(model: DEFAULT_MODEL)
    @model = model
  end

  def generate(prompt:, images: nil)
    body = { model: @model, prompt: prompt, stream: true }
    body[:images] = Array(images).map { |img| strip_base64_prefix(img) } if images

    chunks = stream_request('/api/generate', body)
    chunks.map { |chunk| chunk['response'] }.compact.join
  end

  def chat(messages:)
    formatted = messages.map do |msg|
      m = { role: msg[:role], content: msg[:content] }
      m[:images] = Array(msg[:images]) if msg[:images]
      m
    end

    body = { model: @model, messages: formatted, stream: true }

    chunks = stream_request('/api/chat', body)
    chunks.map { |chunk| chunk.dig('message', 'content') }.compact.join
  end

  private

  def strip_base64_prefix(str)
    str.sub(%r{^data:image/[^;]+;base64,}, '')
  end

  def stream_request(path, body)
    http = build_http_client(path)
    request = build_post_request(path, body)

    chunks = []
    http.request(request) do |response|
      unless response.is_a?(Net::HTTPSuccess)
        raise RequestError, "Ollama API error (#{response.code}): #{response.body}"
      end

      chunks.concat(parse_stream(response))
    end
    chunks
  end

  def build_http_client(path)
    uri = URI("#{BASE_URL}#{path}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    http.read_timeout = TIMEOUT
    http
  end

  def build_post_request(path, body)
    uri = URI("#{BASE_URL}#{path}")
    request = Net::HTTP::Post.new(uri.path, { 'Content-Type' => 'application/json' })
    request.body = body.to_json
    request
  end

  def parse_stream(response)
    chunks = []
    buffer = +''
    response.read_body do |fragment|
      buffer << fragment
      while (newline_index = buffer.index("\n"))
        line = buffer.slice!(0, newline_index + 1).strip
        next if line.empty?

        chunks << JSON.parse(line)
      end
    end
    chunks << JSON.parse(buffer.strip) if buffer.strip.length.positive?
    chunks
  end
end
