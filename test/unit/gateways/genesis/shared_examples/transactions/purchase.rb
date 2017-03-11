module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Genesis
      module SharedExamples
        module Transactions
          module Purchase

            def test_successful_purchase
              successful_purchase_response = successful_init_trx_response(TransactionTypes::SALE)

              @gateway.expects(:ssl_post).returns(successful_purchase_response)

              response = @gateway.purchase(@amount, @credit_card, @options)

              expect_successful_response(response,
                                         transaction_type: TransactionTypes::SALE,
                                         unique_id:        RESPONSE_SUCCESS_UNQ_ID)
            end

            def test_failed_purchase
              failed_purchase_response = failed_init_trx_response(TransactionTypes::SALE)

              @gateway.expects(:ssl_post).returns(failed_purchase_response)

              response = @gateway.purchase(@amount, @credit_card, @options)

              expect_failed_response(response,
                                     status:           TransactionStates::DECLINED,
                                     transaction_type: TransactionTypes::SALE,
                                     unique_id:        RESPONSE_FAILED_UNQ_ID,
                                     code:             response_code_invalid_card_error)
            end
          end
        end
      end
    end
  end
end
