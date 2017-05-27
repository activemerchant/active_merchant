module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Genesis
      module Api
        module Errors

          RESPONSE_CODES = {
            undefined_error:                  1,
            invalid_request:                  11,
            merchant_login_failed:            12,
            merchant_not_configured:          13,
            invalid_transaction_param:        14,
            transaction_not_allowed:          15,
            system_error:                     100,
            maintenance_error:                101,
            authentication_error:             110,
            configuration_error:              120,
            communication_error:              200,
            connection_error:                 210,
            account_error:                    220,
            timeout_error:                    230,
            response_error:                   240,
            parsing_error:                    250,
            input_data_error:                 300,
            invalid_transaction_type_error:   310,
            input_data_missing_error:         320,
            input_data_format_error:          330,
            input_data_invalid_error:         340,
            invalid_xml_error:                350,
            invalid_content_type_error:       360,
            workflow_error:                   400,
            reference_not_found_error:        410,
            reference_workflow_error:         420,
            reference_invalidated_error:      430,
            reference_mismatch_error:         440,
            double_transaction_error:         450,
            txn_not_found_error:              460,
            processing_error:                 500,
            invalid_card_error:               510,
            expired_card_error:               520,
            transaction_pending_error:        530,
            credit_exceeded_error:            540,
            risk_error:                       600,
            bin_country_check_error:          609,
            card_blacklist_error:             610,
            bin_blacklist_error:              611,
            country_blacklist_error:          612,
            ip_blacklist_error:               613,
            blacklist_error:                  614,
            card_whitelist_error:             615,
            card_limit_exceeded_error:        620,
            terminal_limit_exceeded_error:    621,
            contract_limit_exceeded_error:    622,
            card_velocity_exceeded_error:     623,
            card_ticket_size_exceeded_error:  624,
            user_limit_exceeded_error:        625,
            multiple_failure_detection_error: 626,
            cs_detection_error:               627,
            recurring_limit_exceeded_error:   628,
            avs_error:                        690,
            max_mind_risk_error:              691,
            threat_metrix_risk_error:         692,
            remote_error:                     900,
            remote_system_error:              910,
            remote_configuration_error:       920,
            remote_data_error:                930,
            remote_workflow_error:            940,
            remote_timeout_error:             950,
            remote_connection_error:          960
          }.freeze

          ISSUER_RESPONSE_CODES = {
            approved:                 '00',
            card_issue:               '02',
            invalid_merchant:         '03',
            invalid_txn_for_terminal: '06'
          }.freeze

          FRAUDULENT_CODES = [
            RESPONSE_CODES[:risk_error],
            RESPONSE_CODES[:max_mind_risk_error],
            RESPONSE_CODES[:threat_metrix_risk_error]
          ].freeze

          GATEWAY_CONFIG_CODES = [
            RESPONSE_CODES[:undefined_error],
            RESPONSE_CODES[:invalid_request],
            RESPONSE_CODES[:merchant_login_failed],
            RESPONSE_CODES[:merchant_not_configured],
            RESPONSE_CODES[:invalid_transaction_param],
            RESPONSE_CODES[:transaction_not_allowed],
            RESPONSE_CODES[:txn_not_found_error]
          ].freeze
        end
      end
    end
  end
end
