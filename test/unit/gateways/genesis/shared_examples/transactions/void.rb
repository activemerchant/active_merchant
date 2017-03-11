module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Genesis
      module SharedExamples
        module Transactions
          module Void

            def test_successful_void
              successful_void_response = successful_ref_trx_response(TransactionTypes::VOID)

              @gateway.expects(:ssl_post).returns(successful_void_response)

              void = @gateway.void(build_initial_auth_trx.authorization, @options)

              expect_successful_response(void,
                                         transaction_type: TransactionTypes::VOID)
            end

            def test_failed_void
              failed_void_response = failed_ref_trx_response(TransactionTypes::VOID)

              @gateway.expects(:ssl_post).returns(failed_void_response)

              response = @gateway.void('', @options)

              expect_failed_response(response,
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
