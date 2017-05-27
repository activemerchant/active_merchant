%w(authorize capture purchase refund verify void).each do |txn_unit_shared_example|
  require_relative "transactions/#{txn_unit_shared_example}"
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

          def successful_init_trx_response(trx_type)
            <<-SUCCESSFUL_RESPONSE
        {
            "unique_id":          "#{RESPONSE_SUCCESS_UNQ_ID}",
            "authorization_code": #{random_authorization_code},
            "transaction_id":     "#{RESPONSE_SUCCESS_TXN_ID}",
            "timestamp":          "#{response_timestamp}",
            "mode":               "#{RESPONSE_MODE}",
            "descriptor":         "#{RESPONSE_DESCRIPTOR}",
            "amount":             #{response_amount},
            "currency":           "#{currency_code}",
            "transaction_type":   "#{trx_type}",
            "status":             "#{TransactionStates::APPROVED}",
            "response_code":      "00",
            "technical_message":  "#{RESPONSE_SUCCESS_TECH_MSG}",
            "message":            "#{RESPONSE_SUCCESS_MSG}"
        }
            SUCCESSFUL_RESPONSE
          end

          def failed_init_trx_response(trx_type)
            <<-FAILED_RESPONSE
        {
            "unique_id":          "#{RESPONSE_FAILED_UNQ_ID}",
            "authorization_code": #{random_authorization_code},
            "transaction_id":     "#{RESPONSE_FAILED_TXN_ID}",
            "timestamp":          "#{response_timestamp}",
            "mode":               "#{RESPONSE_MODE}",
            "descriptor":         "#{RESPONSE_DESCRIPTOR}",
            "transaction_type":   "#{trx_type}",
            "technical_message":  "#{RESPONSE_FAILED_TECH_MSG_CARD_INVALID}",
            "message":            "#{RESPONSE_FAILED_MSG_CARD_INVALID}",
            "amount":             #{response_amount},
            "currency":           "#{currency_code}",
            "code":               510,
            "status":             "#{TransactionStates::DECLINED}",
            "response_code":      "01"
        }
            FAILED_RESPONSE
          end

          def successful_ref_trx_response(trx_type)
            <<-SUCCESSFUL_RESPONSE
        {
            "unique_id":         "#{RESPONSE_SUCCESS_REF_TXN_UNQ_ID}",
            "transaction_id":    "#{RESPONSE_SUCCESS_REF_TXN_ID}",
            "timestamp":         "#{response_timestamp}",
            "mode":              "#{RESPONSE_MODE}",
            "descriptor":        "#{RESPONSE_DESCRIPTOR}",
            "amount":            #{response_amount},
            "currency":          "#{currency_code}",
            "transaction_type":  "#{trx_type}",
            "status":            "#{TransactionStates::APPROVED}",
            "response_code":     "00",
            "technical_message": "#{RESPONSE_SUCCESS_TECH_MSG}",
            "message":           "#{RESPONSE_SUCCESS_MSG}"
        }
            SUCCESSFUL_RESPONSE
          end

          def failed_ref_trx_response(trx_type)
            message = "#{RESPONSE_FAILED_MSG_INVALID_REF_TXN} #{RESPONSE_MSG_CONTACT_SUPPORT}"
            <<-FAILED_RESPONSE
        {
            "code":             460,
            "status":           "#{TransactionStates::ERROR}",
            "message":          "#{message}",
            "transaction_type": "#{trx_type}"
        }
            FAILED_RESPONSE
          end

          def random_authorization_code
            rand(100_000..999_999)
          end

          def response_amount
            @amount
          end

          def response_timestamp
            Time.now.utc.iso8601
          end

          def currency_code
            @gateway.default_currency
          end
        end
      end
    end
  end
end
