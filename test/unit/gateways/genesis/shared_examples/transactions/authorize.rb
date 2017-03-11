module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Genesis
      module SharedExamples
        module Transactions
          module Authorize

            def test_successful_authorize
              response = build_initial_auth_trx

              expect_successful_response(response,
                                         transaction_type: TransactionTypes::AUTHORIZE,
                                         unique_id:        RESPONSE_SUCCESS_UNQ_ID)
            end

            def test_failed_authorize
              failed_auth_response = failed_init_trx_response(TransactionTypes::AUTHORIZE)

              @gateway.expects(:ssl_post).returns(failed_auth_response)

              response = @gateway.authorize(@amount, @credit_card, @options)

              expect_failed_response(response,
                                     status:           TransactionStates::DECLINED,
                                     transaction_type: TransactionTypes::AUTHORIZE,
                                     unique_id:        RESPONSE_FAILED_UNQ_ID,
                                     code:             response_code_invalid_card_error)
            end
          end
        end
      end
    end
  end
end
