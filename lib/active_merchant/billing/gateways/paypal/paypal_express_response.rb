module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PaypalExpressResponse < Response
      def email
        @params['PayerInfo']['Payer']
      end
      
      def name
        payer = @params['PayerInfo']['PayerName']
        [payer['FirstName'], payer['MiddleName'], payer['LastName']].compact.join(' ')
      end
      
      def token
        @params['Token']
      end
      
      def payer_id
        @params['PayerInfo']['PayerID']
      end
      
      def payer_country
        @params['PayerInfo']['PayerCountry']
      end
      
      # PayPal returns a contact telephone number only if your Merchant account profile settings require that the buyer enter one.
      def contact_phone
        @params['ContactPhone']
      end
      
      def address
        address = @params['PaymentDetails']['ShipToAddress']
        {  'name'       => address['Name'],
           'company'    => @params['PayerInfo']['PayerBusiness'],
           'address1'   => address['Street1'],
           'address2'   => address['Street2'],
           'city'       => address['CityName'],
           'state'      => address['StateOrProvince'],
           'country'    => address['Country'],
           'zip'        => address['PostalCode'],
           'phone'      => contact_phone || address['Phone']
        }
      end
    end
  end
end
