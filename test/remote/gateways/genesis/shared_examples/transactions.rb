%w(authorize capture purchase refund verify void).each do |txn_remote_shared_example|
  require_relative "transactions/#{txn_remote_shared_example}"
end

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Genesis
      module SharedExamples
        module Transactions

          include Purchase
          include Authorize
          include Capture
          include Refund
          include Void
          include Verify

          private

          def check_response_assertions(response, assertions)
            assertions.each do |key, value|
              next unless value.present?

              expected_value = response.params[key.to_s]

              return assert_includes(value, expected_value) if value.is_a? Array

              assert_equal(value, expected_value)
            end
          end

          def error_transaction_expected?(assertions = {})
            assertions.key?('code') && !Helpers::Response.configuration_error?(assertions['code'])
          end

          def expect_successful_response(response, transaction_type)
            assert response
            assert_success response
            assert_nil response.params['code']

            check_response_assertions(response,
                                      transaction_type: transaction_type,
                                      response_code:    issuer_code_approved)

            assert response.message
            assert_nil response.error_code

            check_response_txn_id(response)
            check_response_authorization(response, transaction_type)
          end

          def expect_failed_response(response, assertions = {})
            assert response
            assert_failure response

            check_response_assertions(response, assertions)

            assert response.message

            check_response_txn_id(response)     if error_transaction_expected?(assertions)
            check_response_error_code(response) if assertions.key?('code')

            assert_nil response.authorization
          end

          def check_response_txn_id(response)
            response_params = response.params

            assert response_params['unique_id']
            assert response_params['transaction_id']
          end

          def check_response_authorization(response, transaction_type)
            response_authorization = response.authorization

            return assert_nil response_authorization if reversed_transaction?(transaction_type)

            assert response_authorization
          end

          def reversed_transaction?(transaction_type)
            Helpers::Response.reversed_transaction?(transaction_type)
          end

          def check_response_error_code(response)
            mapped_response_error_code = Helpers::Response.map_error_code(response.params['code'])

            assert_equal mapped_response_error_code, response.error_code
          end
        end
      end
    end
  end
end
