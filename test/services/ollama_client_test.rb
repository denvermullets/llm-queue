require 'test_helper'

class OllamaClientTest < ActiveSupport::TestCase
  setup do
    @client = OllamaClient.new
  end

  test 'generate sends prompt and returns concatenated response text' do
    chunks = [
      { 'response' => 'Hi ' },
      { 'response' => 'there' },
      { 'response' => '', 'done' => true }
    ]

    with_fake_stream(chunks) do |calls|
      result = @client.generate(prompt: 'Hello')
      assert_equal 'Hi there', result
      assert_equal '/api/generate', calls.first[:path]
    end
  end

  test 'generate includes images in request body' do
    chunks = [{ 'response' => 'An image', 'done' => true }]

    with_fake_stream(chunks) do |calls|
      @client.generate(prompt: 'Describe', images: ['data:image/png;base64,abc123'])
      assert_equal ['abc123'], calls.first[:body][:images]
    end
  end

  test 'generate strips base64 prefix from images' do
    chunks = [{ 'response' => 'ok', 'done' => true }]

    with_fake_stream(chunks) do |calls|
      @client.generate(prompt: 'test', images: ['data:image/jpeg;base64,rawdata'])
      assert_equal ['rawdata'], calls.first[:body][:images]
    end
  end

  test 'generate does not include images key when nil' do
    chunks = [{ 'response' => 'ok', 'done' => true }]

    with_fake_stream(chunks) do |calls|
      @client.generate(prompt: 'test')
      assert_nil calls.first[:body][:images]
    end
  end

  test 'chat sends messages and returns concatenated content' do
    chunks = [
      { 'message' => { 'content' => 'Re' } },
      { 'message' => { 'content' => 'ply' } },
      { 'done' => true }
    ]

    with_fake_stream(chunks) do |calls|
      result = @client.chat(messages: [{ role: 'user', content: 'Hi' }])
      assert_equal 'Reply', result
      assert_equal '/api/chat', calls.first[:path]
    end
  end

  test 'uses custom model' do
    client = OllamaClient.new(model: 'llama3')
    chunks = [{ 'response' => 'ok', 'done' => true }]

    with_fake_stream(chunks) do |calls|
      client.generate(prompt: 'test')
      assert_equal 'llama3', calls.first[:body][:model]
    end
  end
end
