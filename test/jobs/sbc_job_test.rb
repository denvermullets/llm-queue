require 'test_helper'

class SbcJobTest < ActiveSupport::TestCase
  test 'processes image request and stores result' do
    request = llm_requests(:sbc_pending)
    fake = Object.new
    fake.define_singleton_method(:generate) { |**| 'A cat sitting on a mat' }

    with_fake_ollama(fake) do
      SbcJob.perform_now(request.id)
    end

    request.reload
    assert_equal 'completed', request.status
    assert_equal 'A cat sitting on a mat', request.response['result']
  end

  test 'uses default prompt when none provided' do
    request = LlmRequest.create!(queue_name: 'sbc', request_type: 'image', payload: { 'images' => ['img'] })
    received_args = nil
    fake = Object.new
    fake.define_singleton_method(:generate) do |**args|
      received_args = args
      'result'
    end

    with_fake_ollama(fake) do
      SbcJob.perform_now(request.id)
    end

    assert_equal 'Describe this image', received_args[:prompt]
  end

  test 'marks request as failed on error' do
    request = llm_requests(:sbc_pending)
    fake = Object.new
    fake.define_singleton_method(:generate) { |**| raise StandardError, 'timeout' }

    with_fake_ollama(fake) do
      assert_raises(StandardError) { SbcJob.perform_now(request.id) }
    end

    request.reload
    assert_equal 'failed', request.status
    assert_equal 'timeout', request.response['error']
  end

  test 'is enqueued on the sbc queue' do
    assert_equal 'sbc', SbcJob.new.queue_name
  end
end
