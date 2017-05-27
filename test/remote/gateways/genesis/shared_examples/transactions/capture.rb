module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Genesis
      module SharedExamples
        module Transactions
          module Capture

            def test_successful_mastercard_capture
              add_successful_description('MasterCard Capture')
              add_credit_cards(:mastercard)

              auth = @gateway.authorize(@amount, @mastercard, @order_details)
              capture = @gateway.capture(@amount, auth.authorization, @order_details)

              expect_successful_response(capture, TransactionTypes::CAPTURE)
            end

            def test_successful_visa_capture
              add_successful_description('Visa Capture')
              add_3d_credit_cards

              auth = @gateway.authorize(@amount, @visa_3d_enrolled, @order_details)
              capture = @gateway.capture(@amount, auth.authorization, @order_details)

              expect_successful_response(capture, TransactionTypes::CAPTURE)
            end

            def test_partial_visa_capture
              add_successful_description('Partial Visa Capture')
              add_credit_cards(:visa)

              auth = @gateway.authorize(@amount, @approved_visa, @order_details)
              capture = @gateway.capture(@amount - 76, auth.authorization)

              expect_successful_response(capture, TransactionTypes::CAPTURE)
            end

            def test_failed_capture
              add_failed_description('Capture')

              capture = @gateway.capture(@amount, '')

              expect_failed_response(capture,
                                     status:           TransactionStates::ERROR,
                                     transaction_type: TransactionTypes::CAPTURE,
                                     code:             response_code_txn_not_found_error)
            end
          end
        end
      end
    end
  end
end
