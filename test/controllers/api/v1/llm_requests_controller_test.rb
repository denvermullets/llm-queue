require 'test_helper'

module Api
  module V1
    class LlmRequestsControllerTest < ActionDispatch::IntegrationTest
      # POST /api/v1/:queue

      test 'create enqueues a vek job and returns 201' do
        assert_enqueued_with(job: VekJob) do
          post api_v1_vek_path, params: { payload: { prompt: 'Hello' } }, as: :json
        end

        assert_response :created
        json = response.parsed_body
        assert_equal 'pending', json['status']
        assert_equal 'vek', json['queue']
        assert json['id'].present?
      end

      test 'create enqueues an sbc job with images' do
        assert_enqueued_with(job: SbcJob) do
          post api_v1_sbc_path, params: { payload: { prompt: 'Describe', images: ['base64data'] } }, as: :json
        end

        assert_response :created
        assert_equal 'sbc', response.parsed_body['queue']
      end

      test 'create enqueues a waxc job' do
        assert_enqueued_with(job: WaxcJob) do
          post api_v1_waxc_path, params: { payload: { prompt: 'What is this?' } }, as: :json
        end

        assert_response :created
        assert_equal 'waxc', response.parsed_body['queue']
      end

      test 'create enqueues a ninetynine job' do
        assert_enqueued_with(job: NinetynineJob) do
          post api_v1_ninetynine_path, params: { payload: { prompt: 'Tell me something' } }, as: :json
        end

        assert_response :created
        assert_equal 'ninetynine', response.parsed_body['queue']
      end

      test 'create persists the payload' do
        post api_v1_vek_path, params: { payload: { prompt: 'Test prompt' } }, as: :json
        request = LlmRequest.find(response.parsed_body['id'])
        assert_equal 'Test prompt', request.payload['prompt']
      end

      test 'create sets correct request_type for text queues' do
        post api_v1_vek_path, params: { payload: { prompt: 'Hi' } }, as: :json
        request = LlmRequest.find(response.parsed_body['id'])
        assert_equal 'text', request.request_type
      end

      test 'create sets correct request_type for image queues' do
        post api_v1_sbc_path, params: { payload: { prompt: 'Describe' } }, as: :json
        request = LlmRequest.find(response.parsed_body['id'])
        assert_equal 'image', request.request_type
      end

      test 'create defaults payload to empty hash' do
        post api_v1_vek_path, as: :json
        request = LlmRequest.find(response.parsed_body['id'])
        assert_equal({}, request.payload)
      end

      # GET /api/v1/llm_requests/:id

      test 'show returns the llm request' do
        request = llm_requests(:vek_pending)
        get api_v1_llm_request_path(request)

        assert_response :success
        json = response.parsed_body
        assert_equal request.id, json['id']
        assert_equal 'vek', json['queue_name']
        assert_equal 'text', json['request_type']
        assert_equal 'pending', json['status']
      end

      test 'show returns 404 for missing request' do
        get api_v1_llm_request_path(id: 0)
        assert_response :not_found
      end

      # GET /api/v1/llm_requests

      test 'index returns all requests ordered by priority' do
        get api_v1_llm_requests_path

        assert_response :success
        json = response.parsed_body
        priorities = json.map { |r| r['priority'] }
        assert_equal priorities.sort, priorities
      end

      test 'index filters by queue' do
        get api_v1_llm_requests_path, params: { queue: 'vek' }

        assert_response :success
        json = response.parsed_body
        assert(json.all? { |r| r['queue_name'] == 'vek' })
      end

      test 'index filters by status' do
        get api_v1_llm_requests_path, params: { status: 'pending' }

        assert_response :success
        json = response.parsed_body
        assert(json.all? { |r| r['status'] == 'pending' })
      end

      test 'index filters by both queue and status' do
        get api_v1_llm_requests_path, params: { queue: 'vek', status: 'pending' }

        assert_response :success
        json = response.parsed_body
        assert(json.all? { |r| r['queue_name'] == 'vek' && r['status'] == 'pending' })
      end
    end
  end
end
