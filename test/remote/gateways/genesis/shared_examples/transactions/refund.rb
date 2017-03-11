module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Genesis
      module SharedExamples
        module Transactions
          module Refund

            def test_successful_mastercard_refund
              add_successful_description('MasterCard Refund')
              add_credit_cards(:mastercard)

              sale = @gateway.purchase(@amount, @mastercard, @order_details)
              refund = @gateway.refund(@amount, sale.authorization, @order_details)

              expect_successful_response(refund, TransactionTypes::REFUND)
            end

            def test_partial_visa_3d_refund
              add_successful_description('Visa 3D Partial Refund')
              add_3d_credit_cards

              sale3d = @gateway.purchase(@amount, @visa_3d_enrolled, @order_details)
              refund = @gateway.refund(@amount - 50, sale3d.authorization)

              expect_successful_response(refund, TransactionTypes::REFUND)
            end

            def test_failed_refund
              add_failed_description('Refund')

              refund = @gateway.refund(@amount, '')

              expect_failed_response(refund,
                                     status:           TransactionStates::ERROR,
                                     transaction_type: TransactionTypes::REFUND,
                                     code:             response_code_txn_not_found_error)
            end
          end
        end
      end
    end
  end
end
