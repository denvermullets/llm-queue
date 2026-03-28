class AddWebhookTrackingToLlmRequests < ActiveRecord::Migration[8.1]
  def change
    add_column :llm_requests, :webhook_status, :string
    add_column :llm_requests, :webhook_sent_at, :datetime
    add_column :llm_requests, :webhook_payload, :jsonb
  end
end
