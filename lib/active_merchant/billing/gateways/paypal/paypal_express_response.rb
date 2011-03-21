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
           'phone'      => @params['ContactPhone']
        }
      end
    end
  end
end
