module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Genesis
      module SharedExamples
        module Transactions
          module Verify

            def test_successful_verify
              successful_auth_response = successful_init_trx_response(TransactionTypes::AUTHORIZE)
              successful_void_response = successful_ref_trx_response(TransactionTypes::VOID)

              response = stub_comms(@gateway, :ssl_post) do
                @gateway.verify(@credit_card, @options)
              end.respond_with(successful_auth_response, successful_void_response)

              assert_success response
              expect_successful_response(response,
                                         transaction_type: TransactionTypes::AUTHORIZE,
                                         unique_id:        RESPONSE_SUCCESS_UNQ_ID)
            end

            def test_failed_verify
              failed_auth_response = failed_init_trx_response(TransactionTypes::AUTHORIZE)
              failed_void_response = failed_ref_trx_response(TransactionTypes::VOID)

              response = stub_comms(@gateway, :ssl_post) do
                @gateway.verify(@credit_card, @options)
              end.respond_with(failed_auth_response, failed_void_response)

              expect_failed_response(response,
                                     status:           TransactionStates::DECLINED,
                                     transaction_type: TransactionTypes::AUTHORIZE,
                                     unique_id:        nil,
                                     code:             response_code_invalid_card_error)
            end
          end
        end
      end
    end
  end
end
