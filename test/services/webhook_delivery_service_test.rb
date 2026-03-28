require 'test_helper'

class WebhookDeliveryServiceTest < ActiveSupport::TestCase
  FakeHTTPResponse = Struct.new(:code, :body, :success) do
    alias_method :success?, :success
  end

  test 'delivers webhook POST to callback_url with correct payload' do
    request = llm_requests(:vek_with_callback)
    request.update!(status: 'completed', response: { result: 'done' })

    fake = FakeHTTPResponse.new(200, 'ok', true)

    with_fake_httparty_capture(fake) do |calls|
      WebhookDeliveryService.new(request).deliver

      assert_equal 1, calls.size
      assert_equal 'https://example.com/webhook', calls.first[:args].first

      body = JSON.parse(calls.first[:kwargs][:body])
      assert_equal 'ext-abc-123', body['external_id']
      assert_equal 'completed', body['status']
      assert_equal({ 'result' => 'done' }, body['response'])
      assert body['completed_at'].present?
    end
  end

  test 'sets webhook_status to delivered on success' do
    request = llm_requests(:vek_with_callback)
    request.update!(status: 'completed', response: { result: 'done' })

    fake = FakeHTTPResponse.new(200, 'ok', true)

    with_fake_httparty(fake) do
      WebhookDeliveryService.new(request).deliver
    end

    request.reload
    assert_equal 'delivered', request.webhook_status
    assert_not_nil request.webhook_sent_at
  end

  test 'stores webhook_payload as snapshot of what was sent' do
    request = llm_requests(:vek_with_callback)
    request.update!(status: 'completed', response: { result: 'done' })

    fake = FakeHTTPResponse.new(200, 'ok', true)

    with_fake_httparty(fake) do
      WebhookDeliveryService.new(request).deliver
    end

    request.reload
    assert_equal 'ext-abc-123', request.webhook_payload['external_id']
    assert_equal 'completed', request.webhook_payload['status']
    assert_equal({ 'result' => 'done' }, request.webhook_payload['response'])
  end

  test 'skips delivery when callback_url is nil' do
    request = llm_requests(:vek_pending)
    request.update!(status: 'completed', response: { result: 'done' })

    fake = FakeHTTPResponse.new(200, 'ok', true)

    with_fake_httparty_capture(fake) do |calls|
      WebhookDeliveryService.new(request).deliver
      assert_equal 0, calls.size
    end

    request.reload
    assert_nil request.webhook_status
  end

  test 'sets webhook_status to failed after max retries' do
    request = llm_requests(:vek_with_callback)
    request.update!(status: 'completed', response: { result: 'done' })

    original = HTTParty.method(:post)
    HTTParty.define_singleton_method(:post) do |*_args, **_kwargs|
      raise StandardError, 'connection refused'
    end

    original_sleep = WebhookDeliveryService.instance_method(:sleep)
    WebhookDeliveryService.define_method(:sleep) { |_| nil }

    WebhookDeliveryService.new(request).deliver

    request.reload
    assert_equal 'failed', request.webhook_status
    assert_nil request.webhook_sent_at
  ensure
    HTTParty.define_singleton_method(:post, original)
    WebhookDeliveryService.define_method(:sleep, original_sleep) if original_sleep
  end

  test 'retries on failure before giving up' do
    request = llm_requests(:vek_with_callback)
    request.update!(status: 'completed', response: { result: 'done' })

    call_count = 0
    original = HTTParty.method(:post)
    HTTParty.define_singleton_method(:post) do |*_args, **_kwargs|
      call_count += 1
      raise StandardError, 'connection refused'
    end

    original_sleep = WebhookDeliveryService.instance_method(:sleep)
    WebhookDeliveryService.define_method(:sleep) { |_| nil }

    WebhookDeliveryService.new(request).deliver

    assert_equal 3, call_count
  ensure
    HTTParty.define_singleton_method(:post, original)
    WebhookDeliveryService.define_method(:sleep, original_sleep) if original_sleep
  end

  test 'delivers failed status on error' do
    request = llm_requests(:vek_with_callback)
    request.update!(status: 'failed', response: { error: 'something broke' })

    fake = FakeHTTPResponse.new(200, 'ok', true)

    with_fake_httparty_capture(fake) do |calls|
      WebhookDeliveryService.new(request).deliver

      body = JSON.parse(calls.first[:kwargs][:body])
      assert_equal 'failed', body['status']
      assert_equal({ 'error' => 'something broke' }, body['response'])
    end
  end
end
