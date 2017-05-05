module BraintreeCommon
  def self.included(base)
    base.supported_countries = %w(US CA AU AD AT BE BG CY CZ DK EE FI FR GI DE GR HU IS IM IE IT LV LI LT LU MT MC NL NO PL PT RO SM SK SI ES SE CH TR GB)
    base.supported_cardtypes = [:visa, :master, :american_express, :discover, :jcb, :diners_club]
    base.homepage_url = 'http://www.braintreepaymentsolutions.com'
    base.display_name = 'Braintree'
    base.default_currency = 'USD'
  end
end
