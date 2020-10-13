module Braintree
  class SubscriptionSearch < AdvancedSearch  # :nodoc:
    multiple_value_field :in_trial_period
    multiple_value_field :ids
    text_fields :id, :transaction_id
    multiple_value_or_text_field :plan_id
    multiple_value_field :status, :allows => Subscription::Status::All
    multiple_value_field :merchant_account_id
    range_fields :created_at, :price, :days_past_due, :billing_cycles_remaining, :next_billing_date
  end
end
