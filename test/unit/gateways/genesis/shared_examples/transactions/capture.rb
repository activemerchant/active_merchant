module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Genesis
      module SharedExamples
        module Transactions
          module Capture

            def test_successful_capture
              successful_capture_response = successful_ref_trx_response(TransactionTypes::CAPTURE)

              @gateway.expects(:ssl_post).returns(successful_capture_response)

              capture = @gateway.capture(@amount, build_initial_auth_trx.authorization, @options)

              expect_successful_response(capture,
                                         transaction_type: TransactionTypes::CAPTURE,
                                         unique_id:        RESPONSE_SUCCESS_REF_TXN_UNQ_ID)
            end

            def test_failed_capture
              failed_capture_response = failed_ref_trx_response(TransactionTypes::CAPTURE)

              @gateway.expects(:ssl_post).returns(failed_capture_response)

              response = @gateway.capture(@amount, '', @options)

              expect_failed_response(response,
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
