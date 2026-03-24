module Api
  module V1
    class LlmRequestsController < ApplicationController
      def create
        llm_request = LlmRequest.new(
          queue_name: queue_name,
          request_type: request_type_for_queue,
          payload: request_params[:payload] || {}
        )

        if llm_request.save
          job_class_for_queue.perform_later(llm_request.id)
          render json: { id: llm_request.id, status: llm_request.status, queue: llm_request.queue_name },
                 status: :created
        else
          render json: { errors: llm_request.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def show
        llm_request = LlmRequest.find(params[:id])
        render json: llm_request.as_json(only: %i[id queue_name request_type status payload response
                                                  created_at updated_at])
      end

      def index
        requests = LlmRequest.by_priority
        requests = requests.where(queue_name: params[:queue]) if params[:queue].present?
        requests = requests.where(status: params[:status]) if params[:status].present?
        render json: requests.as_json(only: %i[id queue_name request_type status priority created_at
                                               updated_at])
      end

      private

      def queue_name
        params[:queue_name]
      end

      def request_params
        params.permit(payload: [:prompt, { images: [] }])
      end

      def request_type_for_queue
        case queue_name
        when 'vek', 'ninetynine' then 'text'
        when 'sbc', 'waxc' then 'image'
        end
      end

      def job_class_for_queue
        case queue_name
        when 'vek' then VekJob
        when 'sbc' then SbcJob
        when 'waxc' then WaxcJob
        when 'ninetynine' then NinetynineJob
        end
      end
    end
  end
end
