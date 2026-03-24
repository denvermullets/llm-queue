require 'test_helper'

class WaxcJobTest < ActiveSupport::TestCase
  test 'processes image request and stores result' do
    request = LlmRequest.create!(
      queue_name: 'waxc', request_type: 'image',
      payload: { 'prompt' => 'What is this?', 'images' => ['imgdata'] }
    )
    fake = Object.new
    fake.define_singleton_method(:generate) { |**| 'A dog' }

    with_fake_ollama(fake) do
      WaxcJob.perform_now(request.id)
    end

    request.reload
    assert_equal 'completed', request.status
    assert_equal 'A dog', request.response['result']
  end

  test 'marks request as failed on error' do
    request = LlmRequest.create!(
      queue_name: 'waxc', request_type: 'image',
      payload: { 'prompt' => 'Describe' }
    )
    fake = Object.new
    fake.define_singleton_method(:generate) { |**| raise StandardError, 'error' }

    with_fake_ollama(fake) do
      assert_raises(StandardError) { WaxcJob.perform_now(request.id) }
    end

    request.reload
    assert_equal 'failed', request.status
  end

  test 'is enqueued on the waxc queue' do
    assert_equal 'waxc', WaxcJob.new.queue_name
  end
end
