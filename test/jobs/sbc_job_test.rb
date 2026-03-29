require 'test_helper'

class SbcJobTest < ActiveSupport::TestCase
  test 'extracts text via OCR then sends to LLM' do
    request = llm_requests(:sbc_pending)
    received_prompt = nil
    fake = Object.new
    fake.define_singleton_method(:generate) do |**args|
      received_prompt = args[:prompt]
      '{"items": []}'
    end

    with_fake_ocr('GROCERY STORE $12.50') do
      with_fake_ollama(fake) do
        SbcJob.perform_now(request.id)
      end
    end

    request.reload
    assert_equal 'completed', request.status
    assert_includes received_prompt, 'GROCERY STORE $12.50'
    assert_nil received_prompt.match(/images/)
  end

  test 'uses default prompt when none provided' do
    request = LlmRequest.create!(queue_name: 'sbc', request_type: 'image', payload: { 'images' => ['img'] })
    received_prompt = nil
    fake = Object.new
    fake.define_singleton_method(:generate) do |**args|
      received_prompt = args[:prompt]
      'result'
    end

    with_fake_ocr('some text') do
      with_fake_ollama(fake) do
        SbcJob.perform_now(request.id)
      end
    end

    assert_includes received_prompt, 'Extract all data from this text.'
  end

  test 'marks request as failed on error' do
    request = llm_requests(:sbc_pending)
    fake = Object.new
    fake.define_singleton_method(:generate) { |**| raise StandardError, 'timeout' }

    with_fake_ocr('some text') do
      with_fake_ollama(fake) do
        assert_raises(StandardError) { SbcJob.perform_now(request.id) }
      end
    end

    request.reload
    assert_equal 'failed', request.status
    assert_equal 'timeout', request.response['error']
  end

  test 'is enqueued on the sbc queue' do
    assert_equal 'sbc', SbcJob.new.queue_name
  end
end
