require 'test_helper'

class OllamaClientTest < ActiveSupport::TestCase
  FakeHTTPResponse = Struct.new(:success, :parsed_response, :code, :body) do
    alias_method :success?, :success
  end

  setup do
    @client = OllamaClient.new
  end

  test 'generate sends prompt and returns response text' do
    fake = FakeHTTPResponse.new(success: true, parsed_response: { 'response' => 'Hi there' })

    with_fake_httparty(fake) do
      result = @client.generate(prompt: 'Hello')
      assert_equal 'Hi there', result
    end
  end

  test 'generate includes images when provided' do
    fake = FakeHTTPResponse.new(success: true, parsed_response: { 'response' => 'An image' })

    with_fake_httparty_capture(fake) do |calls|
      @client.generate(prompt: 'Describe', images: ['data:image/png;base64,abc123'])
      body = JSON.parse(calls.last[:kwargs][:body])
      assert_equal ['abc123'], body['images']
    end
  end

  test 'generate strips base64 prefix from images' do
    fake = FakeHTTPResponse.new(success: true, parsed_response: { 'response' => 'ok' })

    with_fake_httparty_capture(fake) do |calls|
      @client.generate(prompt: 'test', images: ['data:image/jpeg;base64,rawdata'])
      body = JSON.parse(calls.last[:kwargs][:body])
      assert_equal ['rawdata'], body['images']
    end
  end

  test 'generate does not include images key when nil' do
    fake = FakeHTTPResponse.new(success: true, parsed_response: { 'response' => 'ok' })

    with_fake_httparty_capture(fake) do |calls|
      @client.generate(prompt: 'test')
      body = JSON.parse(calls.last[:kwargs][:body])
      assert_nil body['images']
    end
  end

  test 'chat sends messages and returns content' do
    fake = FakeHTTPResponse.new(success: true, parsed_response: { 'message' => { 'content' => 'Reply' } })

    with_fake_httparty(fake) do
      result = @client.chat(messages: [{ role: 'user', content: 'Hi' }])
      assert_equal 'Reply', result
    end
  end

  test 'raises RequestError on non-success response' do
    fake = FakeHTTPResponse.new(success: false, code: 500, body: 'Internal Server Error')

    with_fake_httparty(fake) do
      assert_raises(OllamaClient::RequestError) do
        @client.generate(prompt: 'fail')
      end
    end
  end

  test 'uses custom model' do
    client = OllamaClient.new(model: 'llama3')
    fake = FakeHTTPResponse.new(success: true, parsed_response: { 'response' => 'ok' })

    with_fake_httparty_capture(fake) do |calls|
      client.generate(prompt: 'test')
      body = JSON.parse(calls.last[:kwargs][:body])
      assert_equal 'llama3', body['model']
    end
  end
end
