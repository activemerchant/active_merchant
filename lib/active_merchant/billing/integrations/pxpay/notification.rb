require 'net/http'
module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:

      # # Example:
      #

      module Pxpay
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          include PostsData

          attr_reader :raw

          def initialize(query_string, options={})
            # PxPay appends ?result=...&userid=... to whatever return_url was specified, even if that URL ended with a ?query.
            # So switch the first ? if present to a &
            query_string[/\?/] = '&' if query_string[/\?/]
            super

            raise "missing result parameter from pxpay redirect" if @params["result"].empty?
            raise "missing pxpay api credentials in options" unless @options.has_key?(:credential1) && @options.has_key?(:credential2)

            decrypt_transaction_result(@params["result"])
          end

          # was the notification a validly formed request?
          def acknowledge
            @valid == '1'
          end

          def status
            return 'Failed' unless success?
            return 'Completed' if complete?
            raise 'Notification is for a successful Auth which is not supported'
          end

          def complete?
            @fields['TxnType'] == 'Purchase' && success?
          end

          def cancelled?
            !success?
          end

          # for field definitions see
          # http://www.paymentexpress.com/Technical_Resources/Ecommerce_Hosted/PxPay

          def success?
            @fields['Success'] == '1'
          end

          def gross
            @fields['AmountSettlement']
          end

          def currency
            @fields['CurrencySettlement']
          end

          def account
            @params['userid']
          end

          def item_id
            @fields['TxnId']
          end

          def currency_input
            @fields['CurrencyInput']
          end

          def auth_code
            @fields['AuthCode']
          end

          def card_type
            @fields['CardName']
          end

          def card_holder_name
            @fields['CardHolderName']
          end

          def card_number
            @fields['CardNumber']
          end

          def expiry_date
            @fields['DateExpiry']
          end

          def client_ip
            @fields['ClientInfo']
          end

          def order_id
            @fields['TxnId']
          end

          def payer_email
            @fields['EmailAddress']
          end

          def transaction_id
            @fields['DpsTxnRef']
          end

          def settlement_date
            @fields['DateSettlement']
          end

          # Indication of the uniqueness of a card number
          def txn_mac
            @fields['TxnMac']
          end

          def message
            @fields['ResponseText']
          end

          def optional_data
            [@fields['TxnData1'],@fields['TxnData2'],@fields['TxnData3']]
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
            @fields = {}
            root.elements.each { |e| @fields[e.name] = e.text }
          end

        end
      end
    end
  end
end
