Rails.application.routes.draw do
  get 'up' => 'rails/health#show', as: :rails_health_check

  mount MissionControl::Jobs::Engine, at: '/jobs'

  namespace :api do
    namespace :v1 do
      LlmRequest::QUEUES.each do |queue|
        post queue, to: 'llm_requests#create', defaults: { queue_name: queue }
      end

      resources :llm_requests, only: %i[show index]
    end
  end
end
