require 'net/http'
module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      
      # # Example:
      #

      module Pxpay 
        class Notification < ActiveMerchant::Billing::Integrations::Notification
          include PostsData

          def initialize(query_string, options={})
            super

            raise "missing result parameter from pxpay redirect" if @params["result"].empty?
            raise "missing pxpay api credentials in options" unless @options.has_key?(:account) && @options.has_key?(:credential2)

            decrypt_transaction_result(@params["result"].first)
          end

          # was the notification a validly formed request?
          def valid?
            @valid == '1'
          end

          def status
            success?
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

          def currency_input
            @params['CurrencyInput']
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
            @fields['DpsBillingId']
          end

          def settlement_date
            @fields['DateSettlement']
          end

          # Indication of the uniqueness of a card number
          def txn_mac
            @fields['TxnMac']
          end

          def response_text
            @fields['ResponseText']
          end

          def optional_data
            [@fields['TxnData1'],@fields['TxnData2'],@fields['TxnData3']]
          end

          # When was this payment was received by the client. --unimplemented --
          # always returns nil
          def received_at
            settlement_date
          end

          # They don't pass merchant email back to us -- unimplemented -- always
          # returns nil
          def receiver_email
            nil
          end 

          # Was this a test transaction?
          def test?
            nil
          end

          private
          
          def decrypt_transaction_result(encrypted_result)
            request_xml = REXML::Document.new()
            root = request_xml.add_element('ProcessResponse')

            # TODO retrieve the credentials another way?
            #root.add_element('PxPayUserId').text = @options[:username]
            #root.add_element('PxPayKey').text = @options[:credential2]
            root.add_element('Response').text = encrypted_result

            response_string = ssl_post(Pxpay.token_url, request_xml.to_s)

            puts "\n\n\nresponse_string!\n\n#{response_string}\n"

            response_xml = REXML::Document.new(response_string)
            root = REXML::XPath.first(response_xml)
            @valid = root.attributes["valid"]

            root.elements.each { |e| @params[e.name] = e.text }
          end

        end
      end
    end
  end
end
