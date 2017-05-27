module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Genesis
      module SharedExamples
        module Transactions
          module Refund

            def test_successful_refund
              successful_refund_response = successful_ref_trx_response(TransactionTypes::REFUND)

              @gateway.expects(:ssl_post).returns(successful_refund_response)

              refund = @gateway.refund(@amount, build_initial_purchase_trx.authorization, @options)

              expect_successful_response(refund,
                                         transaction_type: TransactionTypes::REFUND)
            end

            def test_failed_refund
              failed_refund_response = failed_ref_trx_response(TransactionTypes::REFUND)

              @gateway.expects(:ssl_post).returns(failed_refund_response)

              response = @gateway.refund(@amount, '', @options)

              expect_failed_response(response,
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
