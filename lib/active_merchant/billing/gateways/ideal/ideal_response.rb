module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class IdealResponse < Response

      def issuer_list      
        list = @params.values[0]['Directory']['Issuer']
        case list
          when Hash
            return [list]
          when Array
            return list
        end  
      end
      
      def service_url
        @params.values[0]['Issuer']['issuerAuthenticationURL']
      end
      
      def transaction
        @params.values[0]['Transaction']
      end
      
      def error
        @params.values[0]['Error']
      end
      
    end
  end
end