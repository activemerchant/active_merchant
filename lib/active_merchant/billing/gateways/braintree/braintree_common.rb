module BraintreeCommon
  def self.included(base)
    base.supported_countries = ['US']
    base.supported_cardtypes = [:visa, :master, :american_express, :discover, :jcb]
    base.homepage_url = 'http://www.braintreepaymentsolutions.com'
    base.display_name = 'Braintree'
    base.default_currency = 'USD'
  end
end