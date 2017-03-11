module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Genesis
      module SharedExamples
        module Transactions
          module Verify

            def test_successful_mastercard_verify
              add_successful_description('Verification')
              add_credit_cards(:mastercard)

              response = @gateway.verify(@mastercard, @order_details)

              expect_successful_response(response, TransactionTypes::AUTHORIZE)
            end

            def test_failed_visa_verify
              add_failed_description('Verification')
              add_credit_cards(:visa)

              response = @gateway.verify(@declined_visa, @order_details)

              expect_failed_response(response,
                                     status:           TransactionStates::DECLINED,
                                     transaction_type: TransactionTypes::AUTHORIZE,
                                     code:             response_codes_invalid_card)
            end
          end
        end
      end
    end
  end
end
