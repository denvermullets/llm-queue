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

  test 'is enqueued on the vek queue' do
    assert_equal 'vek', VekJob.new.queue_name
  end
end
