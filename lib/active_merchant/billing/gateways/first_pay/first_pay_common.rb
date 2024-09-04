module FirstPayCommon
  def self.included(base)
    base.supported_countries = ['US']
    base.default_currency = 'USD'
    base.money_format = :dollars
    base.supported_cardtypes = %i[visa master american_express discover]

    base.homepage_url = 'http://1stpaygateway.net/'
    base.display_name = '1stPayGateway.Net'
  end

  def supports_scrubbing?
    true
  end
end
