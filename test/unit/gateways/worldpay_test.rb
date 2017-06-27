require 'test_helper'

class WorldpayTest < Test::Unit::TestCase
  include CommStub

  def setup
   @gateway = WorldpayGateway.new(
      :login => 'testlogin',
      :password => 'testpassword'
    )

    @amount = 100
    @credit_card = credit_card('4242424242424242')
    @options = {:order_id => 1}
  end

  def test_successful_authorize
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, @options)
    end.check_request do |endpoint, data, headers|
      assert_match(/4242424242424242/, data)
    end.respond_with(successful_authorize_response)
    assert_success response
    assert_equal 'R50704213207145707', response.authorization
  end

  def test_successful_authorize_by_reference
    response = stub_comms do
      @gateway.authorize(@amount, @options[:order_id].to_s, @options)
    end.check_request do |endpoint, data, headers|
      assert_match(/payAsOrder/, data)
    end.respond_with(successful_authorize_response)
    assert_success response
    assert_equal 'R50704213207145707', response.authorization
  end

  def test_successful_reference_transaction_authorize_with_merchant_code
    response = stub_comms do
      @gateway.authorize(@amount, @options[:order_id].to_s, @options.merge({ merchant_code: 'testlogin2'}))
    end.check_request do |endpoint, data, headers|
      assert_match(/testlogin2/, data)
    end.respond_with(successful_authorize_response)
    assert_success response
    assert_equal 'R50704213207145707', response.authorization
  end

  def test_authorize_passes_ip_and_session_id
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, @options.merge(ip: '127.0.0.1', session_id: '0215ui8ib1'))
    end.check_request do |endpoint, data, headers|
      assert_match(/<session shopperIPAddress="127.0.0.1" id="0215ui8ib1"\/>/, data)
    end.respond_with(successful_authorize_response)
    assert_success response
  end

  def test_failed_authorize
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, @options)
    end.respond_with(failed_authorize_response)
    assert_equal '7', response.error_code
    assert_failure response
  end

  def test_successful_purchase
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.respond_with(successful_authorize_response, successful_capture_response)
    assert_success response
  end

  def test_purchase_passes_correct_currency
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(currency: 'CAD'))
    end.check_request do |endpoint, data, headers|
      assert_match(/CAD/, data)
    end.respond_with(successful_authorize_response, successful_capture_response)
    assert_success response
  end

  def test_purchase_authorize_fails
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.respond_with(failed_authorize_response)
    assert_failure response
    assert_equal 1, response.responses.size
  end

  def test_require_order_id
    assert_raise(ArgumentError) do
      @gateway.authorize(@amount, @credit_card)
    end
  end

  def test_purchase_does_not_run_inquiry
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.respond_with(successful_capture_response)

    assert_success response
    assert_equal %w(authorize capture), response.responses.collect{|e| e.params["action"]}
  end

  def test_successful_void
    response = stub_comms do
      @gateway.void(@options[:order_id], @options)
    end.respond_with(successful_void_inquiry_response, successful_void_response)
    assert_success response
    assert_equal "SUCCESS", response.message
    assert_equal "924e810350efc21a989e0ac7727ce43b", response.params["cancel_received_order_code"]
  end

  def test_void_fails_unless_status_is_authorized
    response = stub_comms do
      @gateway.void(@options[:order_id], @options)
    end.respond_with(failed_void_inquiry_response, successful_void_response)
    assert_failure response
    assert_equal "A transaction status of 'AUTHORISED' is required.", response.message
  end

  def test_successful_refund_for_captured_payment
    response = stub_comms do
      @gateway.refund(@amount, @options[:order_id], @options)
    end.respond_with(successful_refund_inquiry_response('CAPTURED'), successful_refund_response)
    assert_success response
  end

  def test_successful_refund_for_settled_payment
    response = stub_comms do
      @gateway.refund(@amount, @options[:order_id], @options)
    end.respond_with(successful_refund_inquiry_response('SETTLED'), successful_refund_response)
    assert_success response
    assert_equal "05d9f8c622553b1df1fe3a145ce91ccf", response.params['refund_received_order_code']
  end

  def test_successful_refund_for_settled_by_merchant_payment
    response = stub_comms do
      @gateway.refund(@amount, @options[:order_id], @options)
    end.respond_with(successful_refund_inquiry_response('SETTLED_BY_MERCHANT'), successful_refund_response)
    assert_success response
    assert_equal "05d9f8c622553b1df1fe3a145ce91ccf", response.params['refund_received_order_code']
  end

  def test_refund_fails_unless_status_is_captured
    response = stub_comms do
      @gateway.refund(@amount, @options[:order_id], @options)
    end.respond_with(failed_refund_inquiry_response, successful_refund_response)
    assert_failure response
    assert_equal "A transaction status of 'CAPTURED' or 'SETTLED' or 'SETTLED_BY_MERCHANT' is required.", response.message
  end

  def test_full_refund_for_unsettled_payment_forces_void
    response = stub_comms do
      @gateway.refund(@amount, @options[:order_id], @options.merge(force_full_refund_if_unsettled: true))
    end.respond_with(failed_refund_inquiry_response, failed_refund_inquiry_response, successful_void_response)
    assert_success response
    assert "cancel", response.responses.last.params["action"]
  end

  def test_capture
    response = stub_comms do
      response = @gateway.authorize(@amount, @credit_card, @options)
      @gateway.capture(@amount, response.authorization, @options)
    end.respond_with(successful_authorize_response, successful_capture_response)
    assert_success response
  end

  def test_successful_credit
    response = stub_comms do
      @gateway.credit(@amount, @credit_card, @options)
    end.check_request do |endpoint, data, headers|
      assert_match(/<paymentDetails action="REFUND">/, data)
    end.respond_with(successful_credit_response)
    assert_success response
    assert_equal '3d4187536044bd39ad6a289c4339c41c', response.authorization
  end

  def test_description
    stub_comms do
      @gateway.authorize(@amount, @credit_card, @options)
    end.check_request do |endpoint, data, headers|
      assert_match %r(<description>Purchase</description>), data
    end.respond_with(successful_authorize_response)

    stub_comms do
      @gateway.authorize(@amount, @credit_card, @options.merge(description: "Something cool."))
    end.check_request do |endpoint, data, headers|
      assert_match %r(<description>Something cool.</description>), data
    end.respond_with(successful_authorize_response)
  end

  def test_order_content
    stub_comms do
      @gateway.authorize(@amount, @credit_card, @options)
    end.check_request do |endpoint, data, headers|
      assert_no_match %r(orderContent), data
    end.respond_with(successful_authorize_response)

    stub_comms do
      @gateway.authorize(@amount, @credit_card, @options.merge(order_content: "Lots 'o' crazy <data> stuff."))
    end.check_request do |endpoint, data, headers|
      assert_match %r(<orderContent>\s*<!\[CDATA\[Lots 'o' crazy <data> stuff\.\]\]>\s*</orderContent>), data
    end.respond_with(successful_authorize_response)
  end

  def test_capture_time
    stub_comms do
      @gateway.capture(@amount, 'bogus', @options)
    end.check_request do |endpoint, data, headers|
      if data =~ /capture/
        t = Time.now
        assert_tag_with_attributes 'date',
            {'dayOfMonth' => t.day.to_s, 'month' => t.month.to_s, 'year' => t.year.to_s},
          data
      end
    end.respond_with(successful_inquiry_response, successful_capture_response)
  end

  def test_amount_handling
    stub_comms do
      @gateway.authorize(100, @credit_card, @options)
    end.check_request do |endpoint, data, headers|
      assert_tag_with_attributes 'amount',
          {'value' => '100', 'exponent' => '2', 'currencyCode' => 'GBP'},
        data
    end.respond_with(successful_authorize_response)
  end

  def test_currency_exponent_handling
    stub_comms do
      @gateway.authorize(10000, @credit_card, @options.merge(currency: :JPY))
    end.check_request do |endpoint, data, headers|
      assert_tag_with_attributes 'amount',
          {'value' => '100', 'exponent' => '0', 'currencyCode' => 'JPY'},
        data
    end.respond_with(successful_authorize_response)

    stub_comms do
      @gateway.authorize(10000, @credit_card, @options.merge(currency: :OMR))
    end.check_request do |endpoint, data, headers|
      assert_tag_with_attributes 'amount',
          {'value' => '10000', 'exponent' => '3', 'currencyCode' => 'OMR'},
        data
    end.respond_with(successful_authorize_response)
  end

  def test_address_handling
    stub_comms do
      @gateway.authorize(100, @credit_card, @options.merge(billing_address: address))
    end.check_request do |endpoint, data, headers|
      assert_match %r(<firstName>Jim</firstName>), data
      assert_match %r(<lastName>Smith</lastName>), data
      assert_match %r(<address1>456 My Street</address1>), data
      assert_match %r(<address2>Apt 1</address2>), data
      assert_match %r(<postalCode>K1C2N6</postalCode>), data
      assert_match %r(<city>Ottawa</city>), data
      assert_match %r(<state>ON</state>), data
      assert_match %r(<countryCode>CA</countryCode>), data
      assert_match %r(<telephoneNumber>\(555\)555-5555</telephoneNumber>), data
    end.respond_with(successful_authorize_response)

    stub_comms do
      @gateway.authorize(100, @credit_card, @options.merge(billing_address: address.with_indifferent_access))
    end.check_request do |endpoint, data, headers|
      assert_match %r(<firstName>Jim</firstName>), data
      assert_match %r(<lastName>Smith</lastName>), data
      assert_match %r(<address1>456 My Street</address1>), data
      assert_match %r(<address2>Apt 1</address2>), data
      assert_match %r(<postalCode>K1C2N6</postalCode>), data
      assert_match %r(<city>Ottawa</city>), data
      assert_match %r(<state>ON</state>), data
      assert_match %r(<countryCode>CA</countryCode>), data
      assert_match %r(<telephoneNumber>\(555\)555-5555</telephoneNumber>), data
    end.respond_with(successful_authorize_response)

    stub_comms do
      @gateway.authorize(100, @credit_card, @options.merge(address: address))
    end.check_request do |endpoint, data, headers|
      assert_match %r(<firstName>Jim</firstName>), data
      assert_match %r(<lastName>Smith</lastName>), data
      assert_match %r(<address1>456 My Street</address1>), data
      assert_match %r(<address2>Apt 1</address2>), data
      assert_match %r(<postalCode>K1C2N6</postalCode>), data
      assert_match %r(<city>Ottawa</city>), data
      assert_match %r(<state>ON</state>), data
      assert_match %r(<countryCode>CA</countryCode>), data
      assert_match %r(<telephoneNumber>\(555\)555-5555</telephoneNumber>), data
    end.respond_with(successful_authorize_response)

    stub_comms do
      @gateway.authorize(100, @credit_card, @options.merge(billing_address: { phone: "555-3323" }))
    end.check_request do |endpoint, data, headers|
      assert_no_match %r(firstName), data
      assert_no_match %r(lastName), data
      assert_no_match %r(address2), data
      assert_match %r(<address1>N/A</address1>), data
      assert_match %r(<city>N/A</city>), data
      assert_match %r(<postalCode>0000</postalCode>), data
      assert_match %r(<state>N/A</state>), data
      assert_match %r(<countryCode>US</countryCode>), data
      assert_match %r(<telephoneNumber>555-3323</telephoneNumber>), data
    end.respond_with(successful_authorize_response)
  end

  def test_no_address_specified
    stub_comms do
      @gateway.authorize(100, @credit_card, @options)
    end.check_request do |endpoint, data, headers|
      assert_no_match %r(cardAddress), data
      assert_no_match %r(address), data
      assert_no_match %r(firstName), data
      assert_no_match %r(lastName), data
      assert_no_match %r(address1), data
      assert_no_match %r(address2), data
      assert_no_match %r(postalCode), data
      assert_no_match %r(city), data
      assert_no_match %r(state), data
      assert_no_match %r(countryCode), data
      assert_no_match %r(telephoneNumber), data
    end.respond_with(successful_authorize_response)
  end

  def test_address_with_parts_unspecified
    address_with_nils = { address1: nil, city: ' ', state: nil, zip: '  ',
                          country: nil, phone: '555-3323' }

    stub_comms do
      @gateway.authorize(100, @credit_card, @options.merge(billing_address: address_with_nils))
    end.check_request do |endpoint, data, headers|
      assert_no_match %r(firstName), data
      assert_no_match %r(lastName), data
      assert_no_match %r(address2), data
      assert_match %r(<address1>N/A</address1>), data
      assert_match %r(<city>N/A</city>), data
      assert_match %r(<postalCode>0000</postalCode>), data
      assert_match %r(<state>N/A</state>), data
      assert_match %r(<countryCode>US</countryCode>), data
      assert_match %r(<telephoneNumber>555-3323</telephoneNumber>), data
    end.respond_with(successful_authorize_response)
  end

  def test_email
    stub_comms do
      @gateway.authorize(100, @credit_card, @options.merge(email: "eggcellent@example.com"))
    end.check_request do |endpoint, data, headers|
      assert_match %r(<shopperEmailAddress>eggcellent@example.com</shopperEmailAddress>), data
    end.respond_with(successful_authorize_response)

    stub_comms do
      @gateway.authorize(100, @credit_card, @options)
    end.check_request do |endpoint, data, headers|
      assert_no_match %r(shopperEmailAddress), data
    end.respond_with(successful_authorize_response)
  end

  def test_ip
    stub_comms do
      @gateway.authorize(100, @credit_card, @options.merge(ip: "192.137.11.44"))
    end.check_request do |endpoint, data, headers|
      assert_match %r(<session shopperIPAddress="192.137.11.44"/>), data
    end.respond_with(successful_authorize_response)

    stub_comms do
      @gateway.authorize(100, @credit_card, @options)
    end.check_request do |endpoint, data, headers|
      assert_no_match %r(<session), data
    end.respond_with(successful_authorize_response)
  end

  def test_parsing
    response = stub_comms do
      @gateway.authorize(100, @credit_card, @options.merge(address: {address1: "123 Anystreet", country: "US"}))
    end.respond_with(successful_authorize_response)

    assert_equal({
        "action"=>"authorize",
        "amount_currency_code"=>"HKD",
        "amount_debit_credit_indicator"=>"credit",
        "amount_exponent"=>"2",
        "amount_value"=>"15000",
        "avs_result_code_description"=>"UNKNOWN",
        "balance"=>true,
        "balance_account_type"=>"IN_PROCESS_AUTHORISED",
        "card_number"=>"4111********1111",
        "cvc_result_code_description"=>"UNKNOWN",
        "last_event"=>"AUTHORISED",
        "order_status"=>true,
        "order_status_order_code"=>"R50704213207145707",
        "payment"=>true,
        "payment_method"=>"VISA-SSL",
        "payment_service"=>true,
        "payment_service_merchant_code"=>"XXXXXXXXXXXXXXX",
        "payment_service_version"=>"1.4",
        "reply"=>true,
        "risk_score_value"=>"1",
      }, response.params)
  end

  def test_auth
    stub_comms do
      @gateway.authorize(100, @credit_card, @options)
    end.check_request do |endpoint, data, headers|
      assert_equal "Basic dGVzdGxvZ2luOnRlc3RwYXNzd29yZA==", headers['Authorization']
    end.respond_with(successful_authorize_response)
  end

  def test_request_respects_test_mode_on_gateway_instance
    ActiveMerchant::Billing::Base.mode = :production

    @gateway = WorldpayGateway.new(
      :login => 'testlogin',
      :password => 'testpassword',
      :test => true
    )

    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |endpoint, data, headers|
      assert_equal WorldpayGateway.test_url, endpoint
    end.respond_with(successful_authorize_response, successful_capture_response)

  ensure
    ActiveMerchant::Billing::Base.mode = :test
  end

  def test_refund_amount_contains_debit_credit_indicator
    response = stub_comms do
      @gateway.refund(@amount, @options[:order_id], @options)
    end.check_request do |endpoint, data, headers|
      if data =~ /<refund>/
        request_hash = Hash.from_xml(data)
        assert_equal 'credit', request_hash['paymentService']['modify']['orderModification']['refund']['amount']['debitCreditIndicator']
      end
    end.respond_with(successful_refund_inquiry_response, successful_refund_response)
    assert_success response
  end

  def assert_tag_with_attributes(tag, attributes, string)
    assert(m = %r(<#{tag}([^>]+)/>).match(string))
    attributes.each do |attribute, value|
      assert_match %r(#{attribute}="#{value}"), m[1]
    end
  end

  def test_successful_verify
    @gateway.expects(:ssl_post).times(3).returns(successful_authorize_response, successful_void_response)

    response = @gateway.verify(@credit_card, @options)
    assert_success response
  end

  def test_successful_verify_with_failed_void
    @gateway.expects(:ssl_post).times(2).returns(successful_authorize_response, failed_void_response)

    response = @gateway.verify(@credit_card, @options)
    assert_success response
  end

  def test_failed_verify
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    response = @gateway.verify(@credit_card, @options)
    assert_failure response
  end

  def test_transcript_scrubbing
    assert_equal scrubbed_transcript, @gateway.scrub(transcript)
  end

  private

  def successful_authorize_response
    <<-RESPONSE
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE paymentService PUBLIC "-//Bibit//DTD Bibit PaymentService v1//EN"
                                      "http://dtd.bibit.com/paymentService_v1.dtd">
      <paymentService version="1.4" merchantCode="XXXXXXXXXXXXXXX">
        <reply>
          <orderStatus orderCode="R50704213207145707">
            <payment>
              <paymentMethod>VISA-SSL</paymentMethod>
              <amount value="15000" currencyCode="HKD" exponent="2" debitCreditIndicator="credit"/>
              <lastEvent>AUTHORISED</lastEvent>
              <CVCResultCode description="UNKNOWN"/>
              <AVSResultCode description="UNKNOWN"/>
              <balance accountType="IN_PROCESS_AUTHORISED">
                <amount value="15000" currencyCode="HKD" exponent="2" debitCreditIndicator="credit"/>
              </balance>
              <cardNumber>4111********1111</cardNumber>
              <riskScore value="1"/>
            </payment>
          </orderStatus>
        </reply>
      </paymentService>
    RESPONSE
  end

  def failed_authorize_response
    <<-RESPONSE
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE paymentService PUBLIC "-//Bibit//DTD Bibit PaymentService v1//EN"
                                      "http://dtd.bibit.com/paymentService_v1.dtd">
      <paymentService version="1.4" merchantCode="XXXXXXXXXXXXXXX">
        <reply>
          <orderStatus orderCode="R12538568107150952">
            <error code="7">
              <![CDATA[Invalid payment details : Card number : 4111********1111]]>
            </error>
          </orderStatus>
        </reply>
      </paymentService>
    RESPONSE
  end

  def successful_capture_response
    <<-RESPONSE
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE paymentService PUBLIC "-//Bibit//DTD Bibit PaymentService v1//EN"
                                      "http://dtd.bibit.com/paymentService_v1.dtd">
      <paymentService version="1.4" merchantCode="SPREEDLY">
        <reply>
          <ok>
            <captureReceived orderCode="33955f6bb4524813b51836de76228983">
              <amount value="100" currencyCode="GBP" exponent="2" debitCreditIndicator="credit"/>
            </captureReceived>
          </ok>
        </reply>
      </paymentService>
    RESPONSE
  end

  def successful_inquiry_response
    <<-RESPONSE
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE paymentService PUBLIC "-//Bibit//DTD Bibit PaymentService v1//EN"
                                      "http://dtd.bibit.com/paymentService_v1.dtd">
      <paymentService version="1.4" merchantCode="SPREEDLY">
        <reply>
          <orderStatus orderCode="d192c159d5730d339c03fa1a8dc796eb">
            <payment>
              <paymentMethod>VISA-SSL</paymentMethod>
              <amount value="100" currencyCode="GBP" exponent="2" debitCreditIndicator="credit"/>
              <lastEvent>AUTHORISED</lastEvent>
              <CVCResultCode description="UNKNOWN"/>
              <AVSResultCode description="NOT SUPPLIED BY SHOPPER"/>
              <balance accountType="IN_PROCESS_AUTHORISED">
                <amount value="100" currencyCode="GBP" exponent="2" debitCreditIndicator="credit"/>
              </balance>
              <cardNumber>4111********1111</cardNumber>
              <riskScore value="1"/>
            </payment>
            <date dayOfMonth="20" month="04" year="2011" hour="22" minute="24" second="0"/>
          </orderStatus>
        </reply>
      </paymentService>
    RESPONSE
  end

  def successful_void_inquiry_response
    <<-RESPONSE
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE paymentService PUBLIC "-//WorldPay//DTD WorldPay PaymentService v1//EN"
                                      "http://dtd.worldpay.com/paymentService_v1.dtd">
      <paymentService version="1.4" merchantCode="CHARGEBEEM1">
        <reply>
          <orderStatus orderCode="1266bc1b6ab96c026741300418453d43">
            <payment>
              <paymentMethod>VISA-SSL</paymentMethod>
              <amount value="100" currencyCode="GBP" exponent="2" debitCreditIndicator="credit"/>
              <lastEvent>AUTHORISED</lastEvent>
              <CVCResultCode description="NOT SENT TO ACQUIRER"/>
              <AVSResultCode description="NOT SUPPLIED BY SHOPPER"/>
              <cardHolderName><![CDATA[Longbob Longsen]]></cardHolderName>
              <issuerCountryCode>N/A</issuerCountryCode>
              <balance accountType="IN_PROCESS_AUTHORISED">
                <amount value="100" currencyCode="GBP" exponent="2" debitCreditIndicator="credit"/>
              </balance>
              <cardNumber>4111********1111</cardNumber>
              <riskScore value="1"/>
            </payment>
            <date dayOfMonth="05" month="03" year="2013" hour="22" minute="52" second="0"/>
          </orderStatus></reply></paymentService>
    RESPONSE
  end

  def successful_void_response
    <<-RESPONSE
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE paymentService PUBLIC "-//WorldPay//DTD WorldPay PaymentService v1//EN"
                                      "http://dtd.worldpay.com/paymentService_v1.dtd">
      <paymentService version="1.4" merchantCode="CHARGEBEEM1">
        <reply>
          <ok>
            <cancelReceived orderCode="924e810350efc21a989e0ac7727ce43b"/>
          </ok>
        </reply>
      </paymentService>
    RESPONSE
  end

  def failed_void_inquiry_response
    <<-RESPONSE
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE paymentService PUBLIC "-//WorldPay//DTD WorldPay PaymentService v1//EN"
                                      "http://dtd.worldpay.com/paymentService_v1.dtd">
      <paymentService version="1.4" merchantCode="CHARGEBEEM1">
        <reply>
          <orderStatus orderCode="33d6dfa9726198d44a743488cf611d3b">
            <payment>
              <paymentMethod>VISA-SSL</paymentMethod>
              <amount value="100" currencyCode="GBP" exponent="2" debitCreditIndicator="credit"/>
              <lastEvent>SENT_FOR_REFUND</lastEvent>
              <CVCResultCode description="NOT SENT TO ACQUIRER"/>
              <AVSResultCode description="NOT SUPPLIED BY SHOPPER"/>
              <cardHolderName><![CDATA[Longbob Longsen]]></cardHolderName>
              <issuerCountryCode>N/A</issuerCountryCode>
              <balance accountType="IN_PROCESS_CAPTURED">
                <amount value="30" currencyCode="GBP" exponent="2" debitCreditIndicator="credit"/>
              </balance>
              <riskScore value="1"/>
            </payment>
            <date dayOfMonth="05" month="03" year="2013" hour="23" minute="6" second="0"/>
          </orderStatus>
        </reply>
      </paymentService>
    RESPONSE
  end

  def successful_refund_inquiry_response(last_event="CAPTURED")
    <<-RESPONSE
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE paymentService PUBLIC "-//Bibit//DTD Bibit PaymentService v1//EN"
                                "http://dtd.bibit.com/paymentService_v1.dtd">
<paymentService version="1.4" merchantCode="SPREEDLY">
  <reply>
    <orderStatus orderCode="d192c159d5730d339c03fa1a8dc796eb">
      <payment>
        <paymentMethod>VISA-SSL</paymentMethod>
        <amount value="100" currencyCode="GBP" exponent="2" debitCreditIndicator="credit"/>
        <lastEvent>#{ last_event }</lastEvent>
        <CVCResultCode description="UNKNOWN"/>
        <AVSResultCode description="NOT SUPPLIED BY SHOPPER"/>
        <balance accountType="IN_PROCESS_AUTHORISED">
          <amount value="100" currencyCode="GBP" exponent="2" debitCreditIndicator="credit"/>
        </balance>
        <cardNumber>4111********1111</cardNumber>
        <riskScore value="1"/>
      </payment>
      <date dayOfMonth="20" month="04" year="2011" hour="22" minute="24" second="0"/>
    </orderStatus>
  </reply>
</paymentService>
    RESPONSE
  end

  def successful_refund_response
    <<-RESPONSE
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE paymentService PUBLIC "-//WorldPay//DTD WorldPay PaymentService v1//EN"
                                      "http://dtd.worldpay.com/paymentService_v1.dtd">
      <paymentService version="1.4" merchantCode="CHARGEBEEM1">
        <reply>
          <ok>
            <refundReceived orderCode="05d9f8c622553b1df1fe3a145ce91ccf">
              <amount value="35" currencyCode="GBP" exponent="2" debitCreditIndicator="credit"/>
            </refundReceived>
          </ok>
        </reply>
      </paymentService>
    RESPONSE
  end

  def failed_refund_inquiry_response
    <<-RESPONSE
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE paymentService PUBLIC "-//WorldPay//DTD WorldPay PaymentService v1//EN"
                                      "http://dtd.worldpay.com/paymentService_v1.dtd">
      <paymentService version="1.4" merchantCode="CHARGEBEEM1">
        <reply>
          <orderStatus orderCode="417ceff8079ea6a0d8e803f6c0bb2b76">
            <payment>
              <paymentMethod>VISA-SSL</paymentMethod>
              <amount value="100" currencyCode="GBP" exponent="2" debitCreditIndicator="credit"/>
              <lastEvent>AUTHORISED</lastEvent>
              <CVCResultCode description="NOT SENT TO ACQUIRER"/>
              <AVSResultCode description="NOT SUPPLIED BY SHOPPER"/>
              <cardHolderName><![CDATA[Longbob Longsen]]></cardHolderName>
              <issuerCountryCode>N/A</issuerCountryCode>
              <balance accountType="IN_PROCESS_AUTHORISED">
                <amount value="100" currencyCode="GBP" exponent="2" debitCreditIndicator="credit"/>
              </balance>
              <cardNumber>4111********1111</cardNumber>
              <riskScore value="1"/>
            </payment>
            <date dayOfMonth="05" month="03" year="2013" hour="23" minute="19" second="0"/>
          </orderStatus>
        </reply>
      </paymentService>
    RESPONSE
  end

  def failed_void_response
    <<-REQUEST
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE paymentService PUBLIC "-//WorldPay//DTD WorldPay PaymentService v1//EN" "http://dtd.worldpay.com/paymentService_v1.dtd">
      <paymentService version="1.4" merchantCode="CHARGEBEEM1">
        <reply>
          <orderStatus orderCode="non_existent_authorization">
            <error code="5">
              <![CDATA[Could not find payment for order]]>
            </error>
          </orderStatus>
        </reply>
      </paymentService>
    REQUEST
  end

  def successful_credit_response
    <<-RESPONSE
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE paymentService PUBLIC "-//WorldPay//DTD WorldPay PaymentService v1//EN"
                                      "http://dtd.worldpay.com/paymentService_v1.dtd">
      <paymentService version="1.4" merchantCode="SPREEDLYCFT">
        <reply>
          <ok>
            <refundReceived orderCode="3d4187536044bd39ad6a289c4339c41c">
              <amount value="100" currencyCode="GBP" exponent="2" debitCreditIndicator="credit"/>
            </refundReceived>
          </ok>
        </reply>
      </paymentService>
    RESPONSE
  end

  def sample_authorization_request
    <<-REQUEST
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE paymentService PUBLIC "-//RBS WorldPay//DTD RBS WorldPay PaymentService v1//EN" "http://dtd.wp3.rbsworldpay.com/paymentService_v1.dtd">
      <paymentService merchantCode="XXXXXXXXXXXXXXX" version="1.4">
      <submit>
        <order installationId="0000000000" orderCode="R85213364408111039">
          <description>Products Products Products</description>
          <amount value="100" exponent="2" currencyCode="HKD"/>
          <orderContent>Products Products Products</orderContent>
          <paymentDetails>
            <VISA-SSL>
              <cardNumber>4242424242424242</cardNumber>
              <expiryDate>
                <date month="09" year="2011"/>
              </expiryDate>
              <cardHolderName>Jim Smith</cardHolderName>
              <cvc>123</cvc>
              <cardAddress>
                <address>
                  <firstName>Jim</firstName>
                  <lastName>Smith</lastName>
                  <street>456 My Street</street>
                  <houseName>Apt 1</houseName>
                  <postalCode>K1C2N6</postalCode>
                  <city>Ottawa</city>
                  <state>ON</state>
                  <countryCode>CA</countryCode>
                  <telephoneNumber>(555)555-5555</telephoneNumber>
                </address>
              </cardAddress>
            </VISA-SSL>
            <session id="asfasfasfasdgvsdzvxzcvsd" shopperIPAddress="127.0.0.1"/>
          </paymentDetails>
          <shopper>
            <browser>
              <acceptHeader>application/json, text/javascript, */*</acceptHeader>
              <userAgentHeader>Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.9.0.19</userAgentHeader>
            </browser>
          </shopper>
        </order>
      </submit>
      </paymentService>
    REQUEST
  end

  def transcript
    <<-TRANSCRIPT
    <paymentService version="1.4" merchantCode="CHARGEBEEM1">
      <submit>
        <order orderCode="4efd348dbe6708b9ec9c118322e0954f">
          <description>Purchase</description>
          <amount value="100" currencyCode="GBP" exponent="2"/>
          <paymentDetails>
            <VISA-SSL>
              <cardNumber>4111111111111111</cardNumber>
              <expiryDate>
                <date month="09" year="2016"/>
              </expiryDate>
              <cardHolderName>Longbob Longsen</cardHolderName>
              <cvc>123</cvc>
              <cardAddress>
                <address>
                  <address1>N/A</address1>
                  <postalCode>0000</postalCode>
                  <city>N/A</city>
                  <state>N/A</state>
                  <countryCode>US</countryCode>
                </address>
              </cardAddress>
            </VISA-SSL>
          </paymentDetails>
          <shopper>
            <shopperEmailAddress>wow@example.com</shopperEmailAddress>
          </shopper>
        </order>
      </submit>
    </paymentService>
    TRANSCRIPT
  end

  def scrubbed_transcript
    <<-TRANSCRIPT
    <paymentService version="1.4" merchantCode="CHARGEBEEM1">
      <submit>
        <order orderCode="4efd348dbe6708b9ec9c118322e0954f">
          <description>Purchase</description>
          <amount value="100" currencyCode="GBP" exponent="2"/>
          <paymentDetails>
            <VISA-SSL>
              <cardNumber>[FILTERED]</cardNumber>
              <expiryDate>
                <date month="09" year="2016"/>
              </expiryDate>
              <cardHolderName>Longbob Longsen</cardHolderName>
              <cvc>[FILTERED]</cvc>
              <cardAddress>
                <address>
                  <address1>N/A</address1>
                  <postalCode>0000</postalCode>
                  <city>N/A</city>
                  <state>N/A</state>
                  <countryCode>US</countryCode>
                </address>
              </cardAddress>
            </VISA-SSL>
          </paymentDetails>
          <shopper>
            <shopperEmailAddress>wow@example.com</shopperEmailAddress>
          </shopper>
        </order>
      </submit>
    </paymentService>
    TRANSCRIPT
  end
end
