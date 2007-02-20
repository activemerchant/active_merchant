module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PayflowExpressResponse < Response
      def email
        @params['e_mail']
      end
      
      def token
        @params['token']
      end
      
      def payer_id
        @params['payer_id']
      end
      
      def address
        {  'name'       => @params['name'],
           'company'    => nil,
           'address1'   => @params['street'],
           'address2'   => nil,
           'city'       => @params['city'],
           'state'      => @params['state'],
           'country'    => @params['country'],
           'zip'        => @params['zip'],
           'phone'      => nil
        }
      end
    end
  end
end