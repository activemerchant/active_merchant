module BraintreeCommon

  ERROR_CODES = {
    payment_instrument_not_supported: '91577'
  }.freeze

  def self.included(base)
    base.supported_countries = %w(US CA AD AT BE BG HR CY CZ DK EE FI FR GI DE GR GG HU IS IM IE IT JE LV LI LT LU MT MC NL NO PL PT RO SM SK SI ES SE CH TR GB SG HK MY AU NZ)
    base.supported_cardtypes = [:visa, :master, :american_express, :discover, :jcb, :diners_club]
    base.homepage_url = 'http://www.braintreepaymentsolutions.com'
    base.display_name = 'Braintree'
    base.default_currency = 'USD'
  end

  def supports_scrubbing
    true
  end

  def scrub(transcript)
    return "" if transcript.blank?
    transcript.
      gsub(%r((Authorization: Basic )\w+), '\1[FILTERED]').
      gsub(%r((&?ccnumber=)\d*(&?)), '\1[FILTERED]\2').
      gsub(%r((&?cvv=)\d*(&?)), '\1[FILTERED]\2')
  end

  def supports_network_tokenization?
    response = authorize(1, ActiveMerchant::Billing::NetworkTokenizationCreditCard.test_credit_card)
    response_code = response.params['braintree_transaction'].try(:[], 'processor_response_code')
    raise(ActiveMerchant::ActiveMerchantError, response.message) unless response_code

    response_code != ERROR_CODES.fetch(:payment_instrument_not_supported)
  end
end
