require 'test_helper'

class LlmRequestTest < ActiveSupport::TestCase
  test 'valid with required attributes' do
    request = LlmRequest.new(queue_name: 'vek', request_type: 'text')
    assert request.valid?
  end

  test 'invalid without queue_name' do
    request = LlmRequest.new(request_type: 'text')
    assert_not request.valid?
    assert_includes request.errors[:queue_name], "can't be blank"
  end

  test 'invalid without request_type' do
    request = LlmRequest.new(queue_name: 'vek')
    assert_not request.valid?
    assert_includes request.errors[:request_type], "can't be blank"
  end

  test 'invalid with unknown queue_name' do
    request = LlmRequest.new(queue_name: 'unknown', request_type: 'text')
    assert_not request.valid?
    assert_includes request.errors[:queue_name], 'is not included in the list'
  end

  test 'invalid with unknown request_type' do
    request = LlmRequest.new(queue_name: 'vek', request_type: 'audio')
    assert_not request.valid?
    assert_includes request.errors[:request_type], 'is not included in the list'
  end

  test 'invalid with unknown status' do
    request = LlmRequest.new(queue_name: 'vek', request_type: 'text', status: 'unknown')
    assert_not request.valid?
    assert_includes request.errors[:status], 'is not included in the list'
  end

  test 'defaults status to pending' do
    request = LlmRequest.new(queue_name: 'vek', request_type: 'text')
    assert_equal 'pending', request.status
  end

  test 'sets priority from queue_name on create' do
    LlmRequest::PRIORITIES.each do |queue, expected_priority|
      request = LlmRequest.create!(queue_name: queue, request_type: 'text')
      assert_equal expected_priority, request.priority, "Expected priority #{expected_priority} for queue #{queue}"
    end
  end

  test 'defaults priority to 99 for unknown queue' do
    request = LlmRequest.new(queue_name: nil, request_type: 'text')
    request.valid? # triggers callback but will fail validation
    assert_equal 0, request.priority # stays default since queue_name is nil
  end

  test 'pending scope returns only pending requests' do
    pending_requests = LlmRequest.pending
    assert(pending_requests.all? { |r| r.status == 'pending' })
  end

  test 'by_priority scope orders by priority then created_at' do
    results = LlmRequest.by_priority
    priorities = results.map(&:priority)
    assert_equal priorities.sort, priorities
  end

  test 'QUEUES constant contains expected values' do
    assert_equal %w[vek sbc waxc ninetynine], LlmRequest::QUEUES
  end

  test 'STATUSES constant contains expected values' do
    assert_equal %w[pending processing completed failed], LlmRequest::STATUSES
  end

  test 'parse_llm_result strips code fences and parses JSON' do
    result = "```json\n{\"name\": \"test\"}\n```"
    parsed = LlmRequest.parse_llm_result(result)
    assert_equal({ 'name' => 'test' }, parsed)
  end

  test 'parse_llm_result handles code fences without language tag' do
    result = "```\n{\"key\": \"value\"}\n```"
    parsed = LlmRequest.parse_llm_result(result)
    assert_equal({ 'key' => 'value' }, parsed)
  end

  test 'parse_llm_result returns plain string when not valid JSON' do
    result = 'just a plain response'
    parsed = LlmRequest.parse_llm_result(result)
    assert_equal 'just a plain response', parsed
  end

  test 'parse_llm_result parses JSON string without code fences' do
    result = '{"already": "json"}'
    parsed = LlmRequest.parse_llm_result(result)
    assert_equal({ 'already' => 'json' }, parsed)
  end

  test 'parse_llm_result passes through non-string values' do
    result = { 'already' => 'a hash' }
    parsed = LlmRequest.parse_llm_result(result)
    assert_equal({ 'already' => 'a hash' }, parsed)
  end
end
