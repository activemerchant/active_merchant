module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class BeanstreamIppGateway < IppGateway
      self.default_currency = 'AUD'
      self.live_url = 'https://www.bambora.co.nz/interface/api/dts.asmx'
      self.test_url = 'https://demo.bambora.co.nz/interface/api/dts.asmx'
      self.supported_countries = %w[AU NZ]
      self.supported_cardtypes = %i[visa master american_express diners_club jcb]
      self.homepage_url = 'http://www.bambora.co.nz/'
      self.display_name = 'Beanstream IPP'
      self.money_format = :cents

      def initialize(options = {})
        requires!(options, :region, :username, :password, :login)
        
        super
      end
    end
  end
end
