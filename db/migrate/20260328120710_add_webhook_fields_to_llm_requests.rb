class AddWebhookFieldsToLlmRequests < ActiveRecord::Migration[8.1]
  def change
    add_column :llm_requests, :callback_url, :string
    add_column :llm_requests, :external_id, :string
  end
end
