module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:

      module Pxpay
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          include PostsData
          include RequiresParameters

          def initialize(query_string, options={})
            # PxPay appends ?result=...&userid=... to whatever return_url was specified, even if that URL ended with a ?query.
            # So switch the first ? if present to a &
            query_string[/\?/] = '&' if query_string[/\?/]
            super

            @encrypted_params = @params
            @params = {}

            requires! @encrypted_params, "result"
            requires! @options, :credential1, :credential2

            decrypt_transaction_result(@encrypted_params["result"])
          end

          # was the notification a validly formed request?
          def acknowledge(authcode = nil)
            @valid == '1'
          end

          def status
            return 'Failed' unless success?
            return 'Completed' if complete?
            'Error'
          end

          def complete?
            @params['TxnType'] == 'Purchase' && success?
          end

          def cancelled?
            !success?
          end

          # for field definitions see
          # http://www.paymentexpress.com/Technical_Resources/Ecommerce_Hosted/PxPay

          def success?
            @params['Success'] == '1'
          end

          def gross
            @params['AmountSettlement']
          end

          def currency
            @params['CurrencySettlement']
          end

          def account
            @params['userid']
          end

          def item_id
            @params['MerchantReference']
          end

          def currency_input
            @params['CurrencyInput']
          end

          def auth_code
            @params['AuthCode']
          end

          def card_type
            @params['CardName']
          end

          def card_holder_name
            @params['CardHolderName']
          end

          def card_number
            @params['CardNumber']
          end

          def expiry_date
            @params['DateExpiry']
          end

          def client_ip
            @params['ClientInfo']
          end

          def order_id
            item_id
          end

          def payer_email
            @params['EmailAddress']
          end

          def transaction_id
            @params['DpsTxnRef']
          end

          def settlement_date
            @params['DateSettlement']
          end

          # Indication of the uniqueness of a card number
          def txn_mac
            @params['TxnMac']
          end

          def message
            @params['ResponseText']
          end

          def optional_data
            [@params['TxnData1'],@fields['TxnData2'],@fields['TxnData3']]
          end

          # When was this payment was received by the client.
          def received_at
            settlement_date
          end

          # Was this a test transaction?
          def test?
            nil
          end

          private

          def decrypt_transaction_result(encrypted_result)
            request_xml = REXML::Document.new
            root = request_xml.add_element('ProcessResponse')

            root.add_element('PxPayUserId').text = @options[:credential1]
            root.add_element('PxPayKey').text = @options[:credential2]
            root.add_element('Response').text = encrypted_result

            @raw = ssl_post(Pxpay.token_url, request_xml.to_s)

            response_xml = REXML::Document.new(@raw)
            root = REXML::XPath.first(response_xml)
            @valid = root.attributes["valid"]
            @params = {}
            root.elements.each { |e| @params[e.name] = e.text }
          end

        end
      end
    end
  end
end
