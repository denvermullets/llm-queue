class CreateLlmRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :llm_requests do |t|
      t.string :queue_name, null: false
      t.jsonb :payload, null: false, default: {}
      t.string :request_type, null: false
      t.string :status, null: false, default: "pending"
      t.integer :priority, null: false, default: 0
      t.jsonb :response

      t.timestamps
    end

    add_index :llm_requests, :queue_name
    add_index :llm_requests, :status
    add_index :llm_requests, [:priority, :created_at]
  end
end
