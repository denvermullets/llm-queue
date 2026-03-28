require 'test_helper'

class VekJobTest < ActiveSupport::TestCase
  test 'processes request and stores result' do
    request = llm_requests(:vek_pending)
    fake = Object.new
    fake.define_singleton_method(:generate) { |**| 'Generated response' }

    with_fake_ollama(fake) do
      VekJob.perform_now(request.id)
    end

    request.reload
    assert_equal 'completed', request.status
    assert_equal 'Generated response', request.response['result']
  end

  test 'marks request as failed on error' do
    request = llm_requests(:vek_pending)
    fake = Object.new
    fake.define_singleton_method(:generate) { |**| raise StandardError, 'connection refused' }

    with_fake_ollama(fake) do
      assert_raises(StandardError) { VekJob.perform_now(request.id) }
    end

    request.reload
    assert_equal 'failed', request.status
    assert_equal 'connection refused', request.response['error']
  end

  test 'delivers webhook on completion' do
    request = llm_requests(:vek_with_callback)
    fake = Object.new
    fake.define_singleton_method(:generate) { |**| 'Generated response' }

    webhook_calls = []
    original_deliver = WebhookDeliveryService.instance_method(:deliver)
    WebhookDeliveryService.define_method(:deliver) { webhook_calls << @llm_request.id }

    with_fake_ollama(fake) do
      VekJob.perform_now(request.id)
    end

    assert_includes webhook_calls, request.id
  ensure
    WebhookDeliveryService.define_method(:deliver, original_deliver) if original_deliver
  end

  test 'is enqueued on the vek queue' do
    assert_equal 'vek', VekJob.new.queue_name
  end
end
