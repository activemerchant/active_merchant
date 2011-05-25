require 'digest/md5'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Valitor
        module ResponseFields
          def success?
            acknowledge
          end
          alias :complete? :success?
          
          def test?
            @options[:test]
          end
          
          def order
            params['Tilvisunarnumer']
          end
          
          def received_at
            params['Dagsetning']
          end
          
          def transaction_id
            params['VefverslunSalaID']
          end
          
          def status
            "OK"
          end
          
          def card_type
            params['Kortategund']
          end
          
          def card_last_four
            params['KortnumerSidustu']
          end
          
          def authorization_number
            params['Heimildarnumer']
          end
          
          def transaction_number
            params['Faerslunumer']
          end
          
          def customer_name
            params['Nafn']
          end
          
          def customer_address
            params['Heimilisfang']
          end
          
          def customer_zip
            params['Postnumer']
          end
          
          def customer_city
            params['Stadur']
          end
          
          def customer_country
            params['Land']
          end
          
          def customer_email
            params['Tolvupostfang']
          end
          
          def customer_comment
            params['Athugasemdir']
          end
          
          def password
            @options[:credential2]
          end
          
          def acknowledge
            password ? Digest::MD5.hexdigest("#{password}#{order}") == params['RafraenUndirskriftSvar'] : true
          end
        end
      end
    end
  end
end