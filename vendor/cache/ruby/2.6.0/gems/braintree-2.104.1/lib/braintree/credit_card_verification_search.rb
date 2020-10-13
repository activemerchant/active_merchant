module Braintree
  class CreditCardVerificationSearch < AdvancedSearch # :nodoc:
     text_fields(
       :billing_address_details_postal_code,
       :credit_card_cardholder_name,
       :customer_email,
       :customer_id,
       :id,
       :payment_method_token
     )

    equality_fields :credit_card_expiration_date
    partial_match_fields :credit_card_number

    multiple_value_field :credit_card_card_type, :allows => CreditCard::CardType::All
    multiple_value_field :status, :allows => CreditCardVerification::Status::All
    multiple_value_field :ids
    range_fields :created_at
  end
end
