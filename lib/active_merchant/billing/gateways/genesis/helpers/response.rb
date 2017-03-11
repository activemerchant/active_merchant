module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Genesis #:nodoc:
      module Helpers #:nodoc:
        module Response #:nodoc:

          REVERSED_TRANSACTIONS = [
            TransactionTypes::REFUND,
            TransactionTypes::VOID
          ].freeze

          API_RESPONSE_ERROR_CODE_MAPPING = {
            Api::Errors::RESPONSE_CODES[:system_error]             => :processing_error,
            Api::Errors::RESPONSE_CODES[:authentication_error]     => :processing_error,
            Api::Errors::RESPONSE_CODES[:input_data_error]         => :processing_error,
            Api::Errors::RESPONSE_CODES[:input_data_missing_error] => :processing_error,
            Api::Errors::RESPONSE_CODES[:processing_error]         => :card_declined,
            Api::Errors::RESPONSE_CODES[:invalid_card_error]       => :card_declined,
            Api::Errors::RESPONSE_CODES[:expired_card_error]       => :expired_card,
            Api::Errors::RESPONSE_CODES[:card_black_list_error]    => :card_declined,
            Api::Errors::RESPONSE_CODES[:avs_error]                => :incorrect_address
          }.freeze

          INVALID_GATEWAY_RESPONSE_MSG = 'Invalid response received from the Gateway API.'.freeze
          CONTACT_SUPPORT_TEAM_MSG     = 'Please contact support team.'.freeze
          RESPONSE_DESCRIPTION_MSG     = 'The raw response returned by the API was'.freeze

          def self.build_gateway_response(response, test)
            ActiveMerchant::Billing::Response.new(processed?(response),
                                                  response['message'],
                                                  response,
                                                  test:          test,
                                                  authorization: unique_id(response),
                                                  fraud_review:  fraud_detected?(response),
                                                  error_code:    error_code(response))
          end

          def self.map_error_code(error_code)
            return :processing_error unless API_RESPONSE_ERROR_CODE_MAPPING.key?(error_code)

            API_RESPONSE_ERROR_CODE_MAPPING[error_code]
          end

          def self.reversed_transaction?(transaction_type)
            REVERSED_TRANSACTIONS.include?(transaction_type)
          end

          def self.configuration_error?(response_error_code)
            Api::Errors::GATEWAY_CONFIG_CODES.include?(response_error_code)
          end

          def self.unique_id(response)
            return unless transaction_approved?(response)

            response['unique_id'] unless reversed_transaction?(response['transaction_type'])
          end

          def self.error_code(response)
            map_error_code(response['code']) unless processed?(response)
          end

          def self.parse(raw_response)
            parse_json(raw_response)
          rescue JSON::ParserError
            build_error_response(raw_response)
          end

          def self.fraud_detected?(response)
            return false if processed?(response)

            Api::Errors::FRAUDULENT_CODES.include?(response['code'])
          end

          def self.processed?(response)
            return false if response.key?('code')

            transaction_approved?(response)
          end

          def self.build_error_response(response_body)
            {
              'message' => build_invalid_response_message(response_body)
            }
          end

          def self.parse_json(body)
            return {} unless body

            JSON.parse(body)
          end

          def self.transaction_approved?(response)
            return false unless response.key?('status')

            response['status'] == TransactionStates::APPROVED
          end

          def self.build_invalid_response_message(response_body)
            invalid_response_prefix = "#{INVALID_GATEWAY_RESPONSE_MSG}#{CONTACT_SUPPORT_TEAM_MSG}"

            "#{invalid_response_prefix} #{RESPONSE_DESCRIPTION_MSG} #{response_body}"
          end

        end
      end
    end
  end
end
