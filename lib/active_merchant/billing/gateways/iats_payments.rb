module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class IatsPaymentsGateway < AuthorizeNetGateway
      self.live_url = self.test_url = 'https://www.iatspayments.com/netgate/AEGateway.aspx'

      self.homepage_url = 'http://www.iatspayments.com/'
      self.display_name = 'IATSPayments'

      def authorize(money, paysource, options = {})
        raise NotImplementedError
      end

      def capture(money, authorization, options = {})
        raise NotImplementedError
      end

      def void(authorization, options = {})
        raise NotImplementedError
      end

      def refund(money, identification, options = {})
        raise NotImplementedError
      end

      def credit(money, identification, options = {})
        raise NotImplementedError
      end

      private
      def split(response)
        response.split(',')
      end
    end
  end
end
