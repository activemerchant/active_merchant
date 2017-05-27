module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Genesis
      module SharedExamples
        module Transactions
          module Authorize

            def test_successful_visa_authorize
              add_successful_description('Visa Authorization')
              add_credit_cards(:visa)

              auth = @gateway.authorize(@amount, @approved_visa, @order_details)

              expect_successful_response(auth, TransactionTypes::AUTHORIZE)
            end

            def test_successful_visa_authorize_3d
              add_successful_description('Visa 3D Authorization')
              add_3d_credit_cards

              auth = @gateway.authorize(@amount, @visa_3d_enrolled, @order_details)

              expect_successful_response(auth, TransactionTypes::AUTHORIZE_3D)
            end

            def test_failed_visa_authorize
              add_failed_description('Visa Authorization')
              add_credit_cards(:visa)

              authorize = @gateway.authorize(@amount, @declined_visa, @order_details)

              expect_failed_response(authorize,
                                     status:           TransactionStates::DECLINED,
                                     transaction_type: TransactionTypes::AUTHORIZE,
                                     code:             response_codes_invalid_card)
            end

            def test_failed_mastercard_authorize
              add_failed_description('MasterCard Authorization')
              add_credit_cards(:mastercard)

              authorize = @gateway.authorize(@amount, @declined_mastercard, @order_details)
              expect_failed_response(authorize,
                                     status:           TransactionStates::DECLINED,
                                     transaction_type: TransactionTypes::AUTHORIZE,
                                     code:             response_codes_invalid_card)
            end

            def test_failed_authorize_3d_with_enrolled_failing
              add_failed_description('Visa 3D Enrolled Authentication')
              add_3d_credit_cards

              authorize = @gateway.authorize(@amount, @visa_3d_enrolled_fail_auth, @order_details)

              expect_failed_response(authorize,
                                     status:           TransactionStates::DECLINED,
                                     transaction_type: TransactionTypes::AUTHORIZE_3D,
                                     code:             response_code_authentication_error)
            end

            def test_failed_authorize_3d_with_card_not_participating
              add_failed_description('Visa 3D Card Not Participating')
              add_3d_credit_cards

              authorize = @gateway.authorize(@amount, @visa_3d_not_participating, @order_details)

              expect_failed_response(authorize,
                                     status:           TransactionStates::DECLINED,
                                     transaction_type: TransactionTypes::AUTHORIZE_3D,
                                     code:             response_code_processing_error)
            end

            def test_failed_authorize_3d_in_3ds_first_step
              add_failed_description('Visa 3D in 1st Step of 3DS Auth Process')
              add_3d_credit_cards

              authorize = @gateway.authorize(@amount,
                                             @visa_3d_error_first_step_auth,
                                             @order_details)

              expect_failed_response(authorize,
                                     status:           TransactionStates::ERROR,
                                     transaction_type: TransactionTypes::AUTHORIZE_3D,
                                     code:             response_code_authentication_error)
            end

            def test_failed_authorize_3d_in_3ds_second_step
              add_failed_description('Visa 3D in 2nd Step of 3DS Auth Process')
              add_3d_credit_cards

              authorize = @gateway.authorize(@amount,
                                             @visa_3d_error_second_step_auth,
                                             @order_details)

              expect_failed_response(authorize,
                                     status:           TransactionStates::ERROR,
                                     transaction_type: TransactionTypes::AUTHORIZE_3D,
                                     code:             response_code_authentication_error)
            end
          end
        end
      end
    end
  end
end
