module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Genesis
      module SharedExamples
        module Transactions
          module Void

            def test_successful_mastercard_void
              add_successful_description('MasterCard Void')
              add_credit_cards(:mastercard)

              auth = @gateway.authorize(@amount, @mastercard, @order_details)
              void = @gateway.void(auth.authorization, @order_details)

              expect_successful_response(void, TransactionTypes::VOID)
            end

            def test_failed_void
              add_failed_description('Void')

              void = @gateway.void('')

              expect_failed_response(void,
                                     status:           TransactionStates::ERROR,
                                     transaction_type: TransactionTypes::VOID,
                                     code:             response_code_txn_not_found_error)
            end
          end
        end
      end
    end
  end
end
