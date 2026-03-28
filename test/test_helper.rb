ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
require 'rails/test_help'

module ActiveSupport
  class TestCase
    fixtures :all

    def with_fake_ollama(client)
      original = OllamaClient.method(:new)
      OllamaClient.define_singleton_method(:new) { |**| client }
      yield
    ensure
      OllamaClient.define_singleton_method(:new, original)
    end

    # Stubs OllamaClient#stream_request to return pre-built chunks
    # instead of making real HTTP calls
    def with_fake_stream(chunks)
      original = OllamaClient.instance_method(:stream_request)
      captured = []
      OllamaClient.define_method(:stream_request) do |path, body|
        captured << { path: path, body: body }
        chunks
      end
      yield captured
    ensure
      OllamaClient.define_method(:stream_request, original)
    end

    def with_fake_httparty(response)
      original = HTTParty.method(:post)
      HTTParty.define_singleton_method(:post) { |*_args, **_kwargs| response }
      yield
    ensure
      HTTParty.define_singleton_method(:post, original)
    end

    def with_fake_httparty_capture(response)
      calls = []
      original = HTTParty.method(:post)
      HTTParty.define_singleton_method(:post) do |*args, **kwargs|
        calls << { args: args, kwargs: kwargs }
        response
      end
      yield calls
    ensure
      HTTParty.define_singleton_method(:post, original)
    end
  end
end
