require 'test_helper'

class BeanstreamTest < Test::Unit::TestCase
  include CommStub

  def setup
    Base.mode = :test

    @gateway = BeanstreamGateway.new(
                 :login => 'merchant id',
                 :user => 'username',
                 :password => 'password'
               )

    @credit_card = credit_card

    @decrypted_credit_card = ActiveMerchant::Billing::NetworkTokenizationCreditCard.new(
      month: "01",
      year: "2012",
      brand: "visa",
      number: "4030000010001234",
      payment_cryptogram: "cryptogram goes here",
      eci: "an ECI value",
      transaction_id: "transaction ID",
    )

    @check       = check(
                     :institution_number => '001',
                     :transit_number     => '26729'
                   )

    @amount = 1000

    @options = {
      :order_id => '1234',
      :billing_address => {
        :name => 'xiaobo zzz',
        :phone => '555-555-5555',
        :address1 => '1234 Levesque St.',
        :address2 => 'Apt B',
        :city => 'Montreal',
        :state => 'QC',
        :country => 'CA',
        :zip => 'H2C1X8'
      },
      :email => 'xiaobozzz@example.com',
      :subtotal => 800,
      :shipping => 100,
      :tax1 => 100,
      :tax2 => 100,
      :custom => 'reference one'
    }

    @recurring_options = @options.merge(
      :interval => { :unit => :months, :length => 1 },
      :occurrences => 5)
  end

  def test_successful_purchase
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @decrypted_credit_card, @options)
    end.check_request do |method, endpoint, data, headers|
      refute_match(/recurringPayment=true/, data)
    end.respond_with(successful_purchase_response)

    assert_success response
    assert_equal '10000028;15.00;P', response.authorization
  end

  def test_successful_purchase_with_recurring
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @decrypted_credit_card, @options.merge(recurring: true))
    end.check_request do |method, endpoint, data, headers|
      assert_match(/recurringPayment=true/, data)
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_successful_authorize_with_recurring
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.authorize(@amount, @decrypted_credit_card, @options.merge(recurring: true))
    end.check_request do |method, endpoint, data, headers|
      assert_match(/recurringPayment=true/, data)
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_successful_test_request_in_production_environment
    Base.mode = :production
    @gateway.expects(:ssl_post).returns(successful_test_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert response.test?
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_post).returns(unsuccessful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end

  def test_avs_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'R', response.avs_result['code']
  end

  def test_ccv_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'M', response.cvv_result['code']
  end

  def test_successful_check_purchase
    @gateway.expects(:ssl_post).returns(successful_check_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)

    assert_success response
    assert_equal '10000072;15.00;D', response.authorization
    assert_equal 'Approved', response.message
  end

  def test_successful_purchase_with_check
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @check, @options)
    assert_success response
    assert_equal '10000028;15.00;P', response.authorization
  end

  def test_successful_purchase_with_vault
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    vault = rand(100000)+10001

    assert response = @gateway.purchase(@amount, vault, @options)
    assert_success response
    assert_equal '10000028;15.00;P', response.authorization
  end

  def test_successful_verify
    response = stub_comms do
      @gateway.verify(@credit_card)
    end.respond_with(successful_authorize_response, unsuccessful_void_response)
    assert_success response
    assert_equal "Approved", response.message
  end

  def test_failed_verify
    response = stub_comms do
      @gateway.verify(@credit_card)
    end.respond_with(unsuccessful_authorize_response, successful_void_response)
    assert_failure response
    assert_equal "DECLINE", response.message
  end


  # Testing Non-American countries

  def test_german_address_sets_state_to_the_required_dummy_value
    @gateway.expects(:commit).with(german_address_params_without_state)
    billing = @options[:billing_address]
    billing[:country]  = 'DE'
    billing[:city]     = 'Berlin'
    billing[:zip]      = '12345'
    billing[:state]    = nil
    @options[:shipping_address] = billing

    @gateway.purchase(@amount, @credit_card, @options)
  end

  def test_brazilian_address_sets_state_and_zip_to_the_required_dummy_values
    @gateway.expects(:commit).with(brazilian_address_params_without_zip_and_state)
    billing = @options[:billing_address]
    billing[:country]  = 'BR'
    billing[:city]     = 'Rio de Janeiro'
    billing[:zip]      = nil
    billing[:state]    = nil
    @options[:shipping_address] = billing

    @gateway.purchase(@amount, @credit_card, @options)
  end

  def test_successful_recurring
    @gateway.expects(:ssl_post).returns(successful_recurring_response)

    response = assert_deprecation_warning(Gateway::RECURRING_DEPRECATION_MESSAGE) do
      @gateway.recurring(@amount, @credit_card, @recurring_options)
    end
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_successful_update_recurring
    @gateway.expects(:ssl_post).returns(successful_recurring_response)

    response = assert_deprecation_warning(Gateway::RECURRING_DEPRECATION_MESSAGE) do
      @gateway.recurring(@amount, @credit_card, @recurring_options)
    end
    assert_success response
    assert_equal 'Approved', response.message

    @gateway.expects(:ssl_post).returns(successful_update_recurring_response)

    response = assert_deprecation_warning(Gateway::RECURRING_DEPRECATION_MESSAGE) do
      @gateway.update_recurring(@amount, @credit_card, @recurring_options.merge(:account_id => response.params["rbAccountId"]))
    end
    assert_success response
    assert_equal "Request successful", response.message
  end

  def test_successful_cancel_recurring
    @gateway.expects(:ssl_post).returns(successful_recurring_response)

    response = assert_deprecation_warning(Gateway::RECURRING_DEPRECATION_MESSAGE) do
      @gateway.recurring(@amount, @credit_card, @recurring_options)
    end
    assert_success response
    assert_equal 'Approved', response.message

    @gateway.expects(:ssl_post).returns(successful_cancel_recurring_response)

    response = assert_deprecation_warning(Gateway::RECURRING_DEPRECATION_MESSAGE) do
      @gateway.cancel_recurring(:account_id => response.params["rbAccountId"])
    end
    assert_success response
    assert_equal "Request successful", response.message
  end

  def test_ip_is_being_sent
    @gateway.expects(:ssl_post).with do |url, data|
      data =~ /customerIp=123\.123\.123\.123/
    end.returns(successful_purchase_response)

    @options[:ip] = "123.123.123.123"
    @gateway.purchase(@amount, @credit_card, @options)
  end

  def test_includes_network_tokenization_fields
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @decrypted_credit_card, @options)
    end.check_request do |method, endpoint, data, headers|
      assert_match(/3DSecureXID/, data)
      assert_match(/3DSecureECI/, data)
      assert_match(/3DSecureCAVV/, data)
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_defaults_state_and_zip_with_country
    address = { country: "AF" }
    @options[:billing_address] = address
    @options[:shipping_address] = address
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @decrypted_credit_card, @options)
    end.check_request do |method, endpoint, data, headers|
      assert_match(/ordProvince=--/, data)
      assert_match(/ordPostalCode=000000/, data)
      assert_match(/shipProvince=--/, data)
      assert_match(/shipPostalCode=000000/, data)
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_no_state_and_zip_default_with_missing_country
    address = { }
    @options[:billing_address] = address
    @options[:shipping_address] = address
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @decrypted_credit_card, @options)
    end.check_request do |method, endpoint, data, headers|
      assert_no_match(/ordProvince=--/, data)
      assert_no_match(/ordPostalCode=000000/, data)
      assert_no_match(/shipProvince=--/, data)
      assert_no_match(/shipPostalCode=000000/, data)
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_sends_email_without_addresses
    @options[:billing_address] = nil
    @options[:shipping_address] = nil
    @options[:shipping_email] = "ship@mail.com"
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @decrypted_credit_card, @options)
    end.check_request do |method, endpoint, data, headers|
      assert_match(/ordEmailAddress=xiaobozzz%40example.com/, data)
      assert_match(/shipEmailAddress=ship%40mail.com/, data)
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_transcript_scrubbing
    assert_equal scrubbed_transcript, @gateway.scrub(transcript)
  end

  private

  def successful_purchase_response
    "cvdId=1&trnType=P&trnApproved=1&trnId=10000028&messageId=1&messageText=Approved&trnOrderNumber=df5e88232a61dc1d0058a20d5b5c0e&authCode=TEST&errorType=N&errorFields=&responseType=T&trnAmount=15%2E00&trnDate=6%2F5%2F2008+5%3A26%3A53+AM&avsProcessed=0&avsId=0&avsResult=0&avsAddrMatch=0&avsPostalMatch=0&avsMessage=Address+Verification+not+performed+f"
  end

  def successful_test_purchase_response
    "merchant_id=100200000&trnId=11011067&authCode=TEST&trnApproved=1&avsId=M&cvdId=1&messageId=1&messageText=Approved&trnOrderNumber=1234"
  end

  def unsuccessful_purchase_response
    "merchant_id=100200000&trnId=11011069&authCode=&trnApproved=0&avsId=0&cvdId=6&messageId=16&messageText=Duplicate+transaction&trnOrderNumber=1234"
  end

  def successful_check_purchase_response
    "trnApproved=1&trnId=10000072&messageId=1&messageText=Approved&trnOrderNumber=5d9f511363a0f35d37de53b4d74f5b&authCode=&errorType=N&errorFields=&responseType=T&trnAmount=15%2E00&trnDate=6%2F4%2F2008+6%3A33%3A55+PM&avsProcessed=0&avsId=0&avsResult=0&avsAddrMatch=0&avsPostalMatch=0&avsMessage=Address+Verification+not+performed+for+this+transaction%2E&trnType=D&paymentMethod=EFT&ref1=reference+one&ref2=&ref3=&ref4=&ref5="
  end

  def successful_authorize_response
    "trnApproved=1&trnId=10100560&messageId=1&messageText=Approved&trnOrderNumber=0b936c13208677aaa00be509c541e7&authCode=TEST&errorType=N&errorFields=&responseType=T&trnAmount=15%2E00&trnDate=9%2F9%2F2015+10%3A10%3A28+AM&avsProcessed=1&avsId=N&avsResult=0&avsAddrMatch=0&avsPostalMatch=0&avsMessage=Street+address+and+Postal%2FZIP+do+not+match%2E&cvdId=1&cardType=VI&trnType=PA&paymentMethod=CC&ref1=reference+one&ref2=&ref3=&ref4=&ref5="
  end

  def unsuccessful_authorize_response
    "trnApproved=0&trnId=10100561&messageId=7&messageText=DECLINE&trnOrderNumber=7eef9f25c6f123572f193bee4a1aa0&authCode=&errorType=N&errorFields=&responseType=T&trnAmount=15%2E00&trnDate=9%2F9%2F2015+10%3A11%3A22+AM&avsProcessed=1&avsId=N&avsResult=0&avsAddrMatch=0&avsPostalMatch=0&avsMessage=Street+address+and+Postal%2FZIP+do+not+match%2E&cvdId=2&cardType=AM&trnType=PA&paymentMethod=CC&ref1=reference+one&ref2=&ref3=&ref4=&ref5="
  end

  def successful_void_response
    "trnApproved=1&trnId=10100563&messageId=1&messageText=Approved&trnOrderNumber=6ca476d1a29da81a5f2d5d2c92ddeb&authCode=TEST&errorType=N&errorFields=&responseType=T&trnAmount=15%2E00&trnDate=9%2F9%2F2015+10%3A13%3A12+AM&avsProcessed=0&avsId=U&avsResult=0&avsAddrMatch=0&avsPostalMatch=0&avsMessage=Address+information+is+unavailable%2E&cvdId=2&cardType=VI&trnType=VP&paymentMethod=CC&ref1=reference+one&ref2=&ref3=&ref4=&ref5="
  end

  def unsuccessful_void_response
    "trnApproved=0&trnId=0&messageId=0&messageText=%3CLI%3EAdjustment+id+must+be+less+than+8+characters%3Cbr%3E&trnOrderNumber=&authCode=&errorType=U&errorFields=adjId&responseType=T&trnAmount=&trnDate=9%2F9%2F2015+10%3A15%3A20+AM&avsProcessed=0&avsId=0&avsResult=0&avsAddrMatch=0&avsPostalMatch=0&avsMessage=Address+Verification+not+performed+for+this+transaction%2E&cardType=&trnType=VP&paymentMethod=CC&ref1=&ref2=&ref3=&ref4=&ref5="
  end

  def brazilian_address_params_without_zip_and_state
    { :shipProvince => '--', :shipPostalCode => '000000', :ordProvince => '--', :ordPostalCode => '000000', :ordCountry => 'BR', :trnCardOwner => 'Longbob Longsen', :shipCity => 'Rio de Janeiro', :ordAddress1 => '1234 Levesque St.', :ordShippingPrice => '1.00', :deliveryEstimate => nil, :shipName => 'xiaobo zzz', :trnCardNumber => '4242424242424242', :trnAmount => '10.00', :trnType => 'P', :ordAddress2 => 'Apt B', :ordTax1Price => '1.00', :shipEmailAddress => 'xiaobozzz@example.com', :trnExpMonth => '09', :ordCity => 'Rio de Janeiro', :shipPhoneNumber => '555-555-5555', :ordName => 'xiaobo zzz', :trnExpYear => next_year, :trnOrderNumber => '1234', :shipCountry => 'BR', :ordTax2Price => '1.00', :shipAddress1 => '1234 Levesque St.', :ordEmailAddress => 'xiaobozzz@example.com', :trnCardCvd => '123', :trnComments => nil, :shippingMethod => nil, :ref1 => 'reference one', :shipAddress2 => 'Apt B', :ordPhoneNumber => '555-555-5555', :ordItemPrice => '8.00' }
  end

  def german_address_params_without_state
    { :shipProvince => '--', :shipPostalCode => '12345', :ordProvince => '--', :ordPostalCode => '12345', :ordCountry => 'DE', :trnCardOwner => 'Longbob Longsen', :shipCity => 'Berlin', :ordAddress1 => '1234 Levesque St.', :ordShippingPrice => '1.00', :deliveryEstimate => nil, :shipName => 'xiaobo zzz', :trnCardNumber => '4242424242424242', :trnAmount => '10.00', :trnType => 'P', :ordAddress2 => 'Apt B', :ordTax1Price => '1.00', :shipEmailAddress => 'xiaobozzz@example.com', :trnExpMonth => '09', :ordCity => 'Berlin', :shipPhoneNumber => '555-555-5555', :ordName => 'xiaobo zzz', :trnExpYear => next_year, :trnOrderNumber => '1234', :shipCountry => 'DE', :ordTax2Price => '1.00', :shipAddress1 => '1234 Levesque St.', :ordEmailAddress => 'xiaobozzz@example.com', :trnCardCvd => '123', :trnComments => nil, :shippingMethod => nil, :ref1 => 'reference one', :shipAddress2 => 'Apt B', :ordPhoneNumber => '555-555-5555', :ordItemPrice => '8.00' }
  end

  def next_year
    (Time.now.year + 1).to_s[/\d\d$/]
  end

  def successful_recurring_response
    "trnApproved=1&trnId=10000072&messageId=1&messageText=Approved&trnOrderNumber=5d9f511363a0f35d37de53b4d74f5b&authCode=&errorType=N&errorFields=&responseType=T&trnAmount=15%2E00&trnDate=6%2F4%2F2008+6%3A33%3A55+PM&avsProcessed=0&avsId=0&avsResult=0&avsAddrMatch=0&avsPostalMatch=0&avsMessage=Address+Verification+not+performed+for+this+transaction%2E&trnType=D&paymentMethod=EFT&ref1=reference+one&ref2=&ref3=&ref4=&ref5="
  end

  def successful_update_recurring_response
    "<response><code>1</code><message>Request successful</message></response>"
  end

  def successful_cancel_recurring_response
    "<response><code>1</code><message>Request successful</message></response>"
  end

  def transcript
    "ref1=reference+one&trnCardOwner=Longbob+Longsen&trnCardNumber=4030000010001234&trnExpMonth=09&trnExpYear=16&trnCardCvd=123&ordName=xiaobo+zzz&ordEmailAddress=xiaobozzz%40example.com&username=awesomesauce&password=sp00nz%21%21"
  end

  def scrubbed_transcript
    "ref1=reference+one&trnCardOwner=Longbob+Longsen&trnCardNumber=[FILTERED]&trnExpMonth=09&trnExpYear=16&trnCardCvd=[FILTERED]&ordName=xiaobo+zzz&ordEmailAddress=xiaobozzz%40example.com&username=awesomesauce&password=[FILTERED]"
  end

end
