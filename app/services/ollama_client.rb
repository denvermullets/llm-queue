class OllamaClient
  BASE_URL = ENV.fetch('OLLAMA_BASE_URL', 'http://localhost:11434')
  DEFAULT_MODEL = ENV.fetch('OLLAMA_MODEL', 'qwen3.5:2b')
  TIMEOUT = ENV.fetch('OLLAMA_TIMEOUT', 300).to_i

  class RequestError < StandardError; end

  def initialize(model: DEFAULT_MODEL)
    @model = model
  end

  def generate(prompt:, images: nil, think: false)
    ensure_model_loaded

    body = { model: @model, prompt: prompt, stream: true, think: think }
    body[:images] = Array(images).map { |img| strip_base64_prefix(img) } if images

    chunks = stream_request('/api/generate', body)
    extract_generate_text(chunks)
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

  def extract_generate_text(chunks)
    response = chunks.map { |c| c['response'] }.compact.join
    return response unless response.empty?

    chunks.map { |c| c['thinking'] }.compact.join
  end

  def ensure_model_loaded
    check_model_available
    warm_up_model
  rescue StandardError => e
    Rails.logger.warn("OllamaClient: warmup failed (#{e.class}: #{e.message}), proceeding anyway")
  end

  def check_model_available
    uri = URI("#{BASE_URL}/api/show")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    http.read_timeout = 10

    request = Net::HTTP::Post.new(uri.path, { 'Content-Type' => 'application/json' })
    request.body = { model: @model }.to_json

    response = http.request(request)
    return if response.is_a?(Net::HTTPSuccess)

    Rails.logger.warn("OllamaClient: model #{@model} not available (#{response.code}), pulling...")
    pull_model
  end

  def warm_up_model
    Rails.logger.info("OllamaClient: warming up model #{@model}")
    warmup_body = { model: @model, prompt: 'hi', stream: false, keep_alive: '30m' }
    warmup_http = build_http_client('/api/generate')
    warmup_http.read_timeout = TIMEOUT
    warmup_req = build_post_request('/api/generate', warmup_body)
    warmup_http.request(warmup_req)
    Rails.logger.info("OllamaClient: model #{@model} is loaded and ready")
  end

  def pull_model
    uri = URI("#{BASE_URL}/api/pull")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    http.read_timeout = 600

    request = Net::HTTP::Post.new(uri.path, { 'Content-Type' => 'application/json' })
    request.body = { name: @model, stream: false }.to_json
    http.request(request)
  end

  def strip_base64_prefix(str)
    str.sub(%r{^data:image/[^;]+;base64,}, '')
  end

  def stream_request(path, body)
    http = build_http_client(path)
    request = build_post_request(path, body)

    chunks = []
    begin
      http.request(request) do |response|
        unless response.is_a?(Net::HTTPSuccess)
          raise RequestError, "Ollama API error (#{response.code}): #{response.body}"
        end

        chunks.concat(parse_stream(response))
      end
    rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Net::OpenTimeout, Net::ReadTimeout => e
      Rails.logger.error("OllamaClient: connection failed to #{BASE_URL}#{path}: #{e.class} - #{e.message}")
      raise RequestError, "Ollama unavailable: #{e.message}"
    end

    Rails.logger.info("OllamaClient: received #{chunks.size} chunks from #{path}")
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
