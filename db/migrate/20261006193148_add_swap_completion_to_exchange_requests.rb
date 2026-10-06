class AddSwapCompletionToExchangeRequests < ActiveRecord::Migration[8.1]
  def change
    # When the swap actually happened (status becomes "completed", see the enum).
    add_column :exchange_requests, :completed_at, :datetime
  end
end
