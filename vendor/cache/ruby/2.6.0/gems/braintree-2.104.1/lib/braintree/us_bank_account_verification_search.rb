module Braintree
  class UsBankAccountVerificationSearch < AdvancedSearch # :nodoc:
     text_fields(
       :id,
       :account_holder_name,
       :routing_number,
       :payment_method_token,
       :customer_id,
       :customer_email,
     )

    multiple_value_field :verification_method, :allows => UsBankAccountVerification::VerificationMethod::All
    multiple_value_field :status, :allows => UsBankAccountVerification::Status::All
    multiple_value_field :ids
    ends_with_fields :account_number
    range_fields :created_at
    equality_fields :account_type
  end
end
