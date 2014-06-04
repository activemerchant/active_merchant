require 'digest/md5'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Valitor
        module ResponseFields
          def success?
            status == 'Completed'
          end
          alias :complete? :success?
          
          def test?
            @options[:test]
          end
          
          def item_id
            params['ReferenceNumber']
          end
          alias :order :item_id
          
          def transaction_id
            params['SaleID']
          end
          
          def currency
            nil
          end
          
          def status
            "Completed" if acknowledge
          end

          def received_at
            Time.parse(params['Date'].to_s)
          end
          
          def gross
            # Valitor does not return the amount
            nil
          end
          
          def card_type
            params['CardType']
          end
          
          def card_last_four
            params['CardNumberMasked']
          end
          
          def authorization_number
            params['AuthorizationNumber']
          end
          
          def transaction_number
            params['TransactionNumber']
          end
          
          def customer_name
            params['Name']
          end
          
          def customer_address
            params['Address']
          end
          
          def customer_zip
            params['PostalCode']
          end
          
          def customer_city
            params['City']
          end
          
          def customer_country
            params['Country']
          end
          
          def customer_email
            params['Email']
          end
          
          def customer_comment
            params['Comments']
          end
          
          def password
            @options[:credential2]
          end
          
          def acknowledge(authcode = nil)
            password ? Digest::MD5.hexdigest("#{password}#{order}") == params['DigitalSignatureResponse'] : true
          end
        end
      end
    end
  end
end
