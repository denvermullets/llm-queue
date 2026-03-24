require 'test_helper'

class NinetynineJobTest < ActiveSupport::TestCase
  test 'processes text request and stores result' do
    request = LlmRequest.create!(
      queue_name: 'ninetynine', request_type: 'text',
      payload: { 'prompt' => 'Tell me a joke' }
    )
    fake = Object.new
    fake.define_singleton_method(:generate) { |**| 'Why did the chicken cross the road?' }

    with_fake_ollama(fake) do
      NinetynineJob.perform_now(request.id)
    end

    request.reload
    assert_equal 'completed', request.status
    assert_equal 'Why did the chicken cross the road?', request.response['result']
  end

  test 'marks request as failed on error' do
    request = LlmRequest.create!(
      queue_name: 'ninetynine', request_type: 'text',
      payload: { 'prompt' => 'Hello' }
    )
    fake = Object.new
    fake.define_singleton_method(:generate) { |**| raise StandardError, 'boom' }

    with_fake_ollama(fake) do
      assert_raises(StandardError) { NinetynineJob.perform_now(request.id) }
    end

    request.reload
    assert_equal 'failed', request.status
    assert_equal 'boom', request.response['error']
  end

  test 'is enqueued on the ninetynine queue' do
    assert_equal 'ninetynine', NinetynineJob.new.queue_name
  end
end
