module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PayuCoGateway < PayuLatamGateway
      self.test_url = 'https://stg.api.payulatam.com/payments-api/4.0/service.cgi'
      self.live_url = 'https://api.payulatam.com/payments-api/4.0/service.cgi'

      INFO_TEST_URL = 'https://stg.api.payulatam.com/reports-api/4.0/service.cgi'
      INFO_LIVE_URL = 'https://api.payulatam.com/reports-api/4.0/service.cgi'

      self.supported_countries = ['CO']
      self.default_currency = 'COP'
      self.supported_cardtypes = [:visa, :master, :american_express, :diners_club]

      self.homepage_url = 'http://payu.com.co/'
      self.display_name = 'PayU Colombia'
    end
  end
end