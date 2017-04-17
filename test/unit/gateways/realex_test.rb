require 'test_helper'

class RealexTest < Test::Unit::TestCase
  class ActiveMerchant::Billing::RealexGateway
    # For the purposes of testing, lets redefine some protected methods as public.
    public :build_purchase_or_authorization_request, :build_refund_request,
      :build_void_request, :build_capture_request, :build_store_payer_request,
      :build_store_payment_request
  end

  def setup
    @login = 'your_merchant_id'
    @password = 'your_secret'
    @account = 'your_account'
    @rebate_secret = 'your_rebate_secret'

    @gateway = RealexGateway.new(
      :login => @login,
      :password => @password,
      :account => @account
    )

    @gateway_with_account = RealexGateway.new(
      :login => @login,
      :password => @password,
      :account => 'bill_web_cengal'
    )

    @credit_card = CreditCard.new(
      :number => '4263971921001307',
      :month => 8,
      :year => 2008,
      :first_name => 'Longbob',
      :last_name => 'Longsen',
      :brand => 'visa'
    )

    @options = {
      :order_id => '1'
    }

    @address = {
      :name => 'Longbob Longsen',
      :address1 => '123 Fake Street',
      :city => 'Belfast',
      :state => 'Antrim',
      :country => 'Northern Ireland',
      :zip => 'BT2 8XX'
    }

    @amount = 100
  end

  def test_hash
    gateway = RealexGateway.new(
      :login => 'thestore',
      :password => 'mysecret'
    )
    Time.stubs(:now).returns(Time.new(2001, 4, 3, 12, 32, 45))
    gateway.expects(:ssl_post).with(anything, regexp_matches(/9af7064afd307c9f988e8dfc271f9257f1fc02f6/)).returns(successful_purchase_response)
    gateway.purchase(29900, credit_card('5105105105105100'), :order_id => 'ORD453-11')
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    assert response.test?
  end

  def test_unsuccessful_purchase
    @gateway.expects(:ssl_post).returns(unsuccessful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_failure response
    assert response.test?
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)
    assert_success @gateway.refund(@amount, '1234;1234;1234')
  end

  def test_unsuccessful_refund
    @gateway.expects(:ssl_post).returns(unsuccessful_refund_response)
    assert_failure @gateway.refund(@amount, '1234;1234;1234')
  end

  def test_deprecated_credit
    @gateway.expects(:ssl_post).returns(successful_refund_response)
    assert_deprecation_warning(Gateway::CREDIT_DEPRECATION_MESSAGE) do
      assert_success @gateway.credit(@amount, '1234;1234;1234')
    end
  end

  def test_successful_store_customer_and_card
    @gateway.expects(:ssl_request).twice.returns(successful_store_customer_response, successful_store_card_response)
    @options[:customer] = 'longbob1'
    @options[:cardref] = 'longbob1-visa'

    assert response = @gateway.store(@credit_card, @options)
    assert_instance_of MultiResponse, response
    assert_success response
    assert_equal 2, response.responses.size

    customer_response = response.responses[0]
    assert_not_nil customer_response.params['result']

    card_response = response.responses[1]
    assert_not_nil card_response.params['result']
  end

  def test_unsuccessful_store_customer
    @gateway.expects(:ssl_request).returns(unsuccessful_store_customer_response)
    @options[:customer] = 'longb@b1'
    @options[:cardref] = 'longbob1-visa'

    assert response = @gateway.store(@credit_card, @options)
    assert_instance_of MultiResponse, response
    assert_failure response
    assert_equal 1, response.responses.size

    customer_response = response.responses[0]
    assert_not_nil customer_response.params['result']
    assert_equal '506', customer_response.params['result']
  end

  def test_supported_countries
    assert_equal ['IE', 'GB', "FR", "BE", "NL", "LU", "IT"], RealexGateway.supported_countries
  end

  def test_supported_card_types
    assert_equal [ :visa, :master, :american_express, :diners_club, :switch, :solo, :laser ], RealexGateway.supported_cardtypes
  end

  def test_avs_result_not_supported
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_nil response.avs_result['code']
  end

  def test_cvv_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'M', response.cvv_result['code']
  end

  def test_malformed_xml
    @gateway.expects(:ssl_post).returns(malformed_unsuccessful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_failure response
    assert_equal '[ test system ] This is  not awesome', response.params['message']
    assert response.test?
  end

  def test_capture_xml
    @gateway.expects(:new_timestamp).returns('20090824160201')

    valid_capture_xml = <<-SRC
<request timestamp="20090824160201" type="settle">
  <merchantid>your_merchant_id</merchantid>
  <account>your_account</account>
  <orderid>1</orderid>
  <pasref>4321</pasref>
  <authcode>1234</authcode>
  <sha1hash>4132600f1dc70333b943fc292bd0ca7d8e722f6e</sha1hash>
</request>
SRC

    assert_xml_equal valid_capture_xml, @gateway.build_capture_request('1;4321;1234', {})
  end

  def test_purchase_xml
    options = {
      :order_id => '1'
    }

    @gateway.expects(:new_timestamp).returns('20090824160201')

    valid_purchase_request_xml = <<-SRC
<request timestamp="20090824160201" type="auth">
  <merchantid>your_merchant_id</merchantid>
  <account>your_account</account>
  <orderid>1</orderid>
  <amount currency="EUR">100</amount>
  <card>
    <number>4263971921001307</number>
    <expdate>0808</expdate>
    <chname>Longbob Longsen</chname>
    <type>VISA</type>
    <issueno></issueno>
    <cvn>
      <number></number>
      <presind></presind>
    </cvn>
  </card>
  <autosettle flag="1"/>
  <sha1hash>3499d7bc8dbacdcfba2286bd74916d026bae630f</sha1hash>
</request>
SRC

    assert_xml_equal valid_purchase_request_xml, @gateway.build_purchase_or_authorization_request(:purchase, @amount, @credit_card, options)
  end

  def test_void_xml
    @gateway.expects(:new_timestamp).returns('20090824160201')

    valid_void_request_xml = <<-SRC
<request timestamp="20090824160201" type="void">
  <merchantid>your_merchant_id</merchantid>
  <account>your_account</account>
  <orderid>1</orderid>
  <pasref>4321</pasref>
  <authcode>1234</authcode>
  <sha1hash>4132600f1dc70333b943fc292bd0ca7d8e722f6e</sha1hash>
</request>
SRC

    assert_xml_equal valid_void_request_xml, @gateway.build_void_request('1;4321;1234', {})
  end

  def test_auth_xml
    options = {
      :order_id => '1'
    }

    @gateway.expects(:new_timestamp).returns('20090824160201')

    valid_auth_request_xml = <<-SRC
<request timestamp="20090824160201" type="auth">
  <merchantid>your_merchant_id</merchantid>
  <account>your_account</account>
  <orderid>1</orderid>
  <amount currency=\"EUR\">100</amount>
  <card>
    <number>4263971921001307</number>
    <expdate>0808</expdate>
    <chname>Longbob Longsen</chname>
    <type>VISA</type>
    <issueno></issueno>
    <cvn>
      <number></number>
      <presind></presind>
    </cvn>
  </card>
  <autosettle flag="0"/>
  <sha1hash>3499d7bc8dbacdcfba2286bd74916d026bae630f</sha1hash>
</request>
SRC

    assert_xml_equal valid_auth_request_xml, @gateway.build_purchase_or_authorization_request(:authorization, @amount, @credit_card, options)
  end

  def test_refund_xml
    @gateway.expects(:new_timestamp).returns('20090824160201')

    valid_refund_request_xml = <<-SRC
<request timestamp="20090824160201" type="rebate">
  <merchantid>your_merchant_id</merchantid>
  <account>your_account</account>
  <orderid>1</orderid>
  <pasref>4321</pasref>
  <authcode>1234</authcode>
  <amount currency="EUR">100</amount>
  <autosettle flag="1"/>
  <sha1hash>ef0a6c485452f3f94aff336fa90c6c62993056ca</sha1hash>
</request>
SRC

    assert_xml_equal valid_refund_request_xml, @gateway.build_refund_request(@amount, '1;4321;1234', {})

  end

  def test_refund_with_rebate_secret_xml
    gateway = RealexGateway.new(:login => @login, :password => @password, :account => @account, :rebate_secret => @rebate_secret)

    gateway.expects(:new_timestamp).returns('20090824160201')

    valid_refund_request_xml = <<-SRC
<request timestamp="20090824160201" type="rebate">
  <merchantid>your_merchant_id</merchantid>
  <account>your_account</account>
  <orderid>1</orderid>
  <pasref>4321</pasref>
  <authcode>1234</authcode>
  <amount currency="EUR">100</amount>
  <refundhash>f94ff2a7c125a8ad87e5683114ba1e384889240e</refundhash>
  <autosettle flag="1"/>
  <sha1hash>ef0a6c485452f3f94aff336fa90c6c62993056ca</sha1hash>
</request>
SRC

    assert_xml_equal valid_refund_request_xml, gateway.build_refund_request(@amount, '1;4321;1234', {})

  end

  def test_store_customer_xml
    options = {
      :order_id => '1',
      :customer => 'longbob1'
    }

    @gateway.expects(:new_timestamp).returns('20090824160201')

    valid_customer_store_xml = <<-SRC
<request timestamp="20090824160201" type="payer-new">
  <merchantid>your_merchant_id</merchantid>
  <account>your_account</account>
  <orderid>1</orderid>
  <payer ref="longbob1">
    <firstname>Longbob</firstname>
    <surname>Longsen</surname>
  </payer>
  <sha1hash>d1a2644000ca28ef00425441d9397fc28ee39e39</sha1hash>
</request>
SRC

    assert_xml_equal valid_customer_store_xml, @gateway.build_store_payer_request(@credit_card, options)

  end

  def test_store_payment_xml
    options = {
      :order_id => '1',
      :customer => 'longbob1',
      :cardref  => 'longbob1-visa'
    }

    @gateway.expects(:new_timestamp).returns('20090824160201')

    valid_payment_store_xml = <<-SRC
<request timestamp="20090824160201" type="card-new">
  <merchantid>your_merchant_id</merchantid>
  <account>your_account</account>
  <orderid>1</orderid>
  <card>
    <number>4263971921001307</number>
    <expdate>0808</expdate>
    <chname>Longbob Longsen</chname>
    <type>VISA</type>
    <issueno></issueno>
    <ref>longbob1-visa</ref>
    <payerref>longbob1</payerref>
  </card>
  <sha1hash>f9d2fa924657dea4144cd81f7320073fd4cf3c36</sha1hash>
</request>
SRC

    assert_xml_equal valid_payment_store_xml, @gateway.build_store_payment_request(@credit_card, options)

  end


  def test_auth_with_address
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    options = {
      :order_id => '1',
      :billing_address => @address,
      :shipping_address => @address
    }

    @gateway.expects(:new_timestamp).returns('20090824160201')

    response = @gateway.authorize(@amount, @credit_card, options)
    assert_instance_of Response, response
    assert_success response
    assert response.test?

  end

  def test_zip_in_shipping_address
    @gateway.expects(:ssl_post).with(anything, regexp_matches(/<code>28\|123<\/code>/)).returns(successful_purchase_response)

    options = {
      :order_id => '1',
      :shipping_address => @address
    }

    @gateway.authorize(@amount, @credit_card, options)
  end

  def test_zip_in_billing_address
    @gateway.expects(:ssl_post).with(anything, regexp_matches(/<code>28\|123<\/code>/)).returns(successful_purchase_response)

    options = {
      :order_id => '1',
      :billing_address => @address
    }

    @gateway.authorize(@amount, @credit_card, options)
  end

  def test_transcript_scrubbing
    assert_equal scrubbed_transcript, @gateway.scrub(transcript)
  end

  private

  def successful_purchase_response
    <<-RESPONSE
<response timestamp='20010427043422'>
  <merchantid>your merchant id</merchantid>
  <account>account to use</account>
  <orderid>order id from request</orderid>
  <authcode>authcode received</authcode>
  <result>00</result>
  <message>[ test system ] message returned from system</message>
  <pasref> realex payments reference</pasref>
  <cvnresult>M</cvnresult>
  <batchid>batch id for this transaction (if any)</batchid>
  <cardissuer>
    <bank>Issuing Bank Name</bank>
    <country>Issuing Bank Country</country>
    <countrycode>Issuing Bank Country Code</countrycode>
    <region>Issuing Bank Region</region>
  </cardissuer>
  <tss>
    <result>89</result>
    <check id="1000">9</check>
    <check id="1001">9</check>
  </tss>
  <sha1hash>7384ae67....ac7d7d</sha1hash>
  <md5hash>34e7....a77d</md5hash>
</response>"
    RESPONSE
  end

  def unsuccessful_purchase_response
    <<-RESPONSE
<response timestamp='20010427043422'>
  <merchantid>your merchant id</merchantid>
  <account>account to use</account>
  <orderid>order id from request</orderid>
  <authcode>authcode received</authcode>
  <result>01</result>
  <message>[ test system ] message returned from system</message>
  <pasref> realex payments reference</pasref>
  <cvnresult>M</cvnresult>
  <batchid>batch id for this transaction (if any)</batchid>
  <cardissuer>
    <bank>Issuing Bank Name</bank>
    <country>Issuing Bank Country</country>
    <countrycode>Issuing Bank Country Code</countrycode>
    <region>Issuing Bank Region</region>
  </cardissuer>
  <tss>
    <result>89</result>
    <check id="1000">9</check>
    <check id="1001">9</check>
  </tss>
  <sha1hash>7384ae67....ac7d7d</sha1hash>
  <md5hash>34e7....a77d</md5hash>
</response>"
    RESPONSE
  end

  def malformed_unsuccessful_purchase_response
    <<-RESPONSE
<response timestamp='20010427043422'>
  <merchantid>your merchant id</merchantid>
  <account>account to use</account>
  <orderid>order id from request</orderid>
  <authcode>authcode received</authcode>
  <result>01</result>
  <message>[ test system ] This is & not awesome</message>
  <pasref> realex payments reference</pasref>
  <cvnresult>M</cvnresult>
  <batchid>batch id for this transaction (if any)</batchid>
  <cardissuer>
    <bank>Issuing Bank Name</bank>
    <country>Issuing Bank Country</country>
    <countrycode>Issuing Bank Country Code</countrycode>
    <region>Issuing Bank Region</region>
  </cardissuer>
  <tss>
    <result>89</result>
    <check id="1000">9</check>
    <check id="1001">9</check>
  </tss>
  <sha1hash>7384ae67....ac7d7d</sha1hash>
  <md5hash>34e7....a77d</md5hash>
</response>"
    RESPONSE
  end

  def successful_refund_response
    <<-RESPONSE
<response timestamp='20010427043422'>
  <merchantid>your merchant id</merchantid>
  <account>account to use</account>
  <orderid>order id from request</orderid>
  <authcode>authcode received</authcode>
  <result>00</result>
  <message>[ test system ] message returned from system</message>
  <pasref> realex payments reference</pasref>
  <cvnresult>M</cvnresult>
  <batchid>batch id for this transaction (if any)</batchid>
  <sha1hash>7384ae67....ac7d7d</sha1hash>
  <md5hash>34e7....a77d</md5hash>
</response>"
    RESPONSE
  end

  def unsuccessful_refund_response
    <<-RESPONSE
<response timestamp='20010427043422'>
  <merchantid>your merchant id</merchantid>
  <account>account to use</account>
  <orderid>order id from request</orderid>
  <authcode>authcode received</authcode>
  <result>508</result>
  <message>[ test system ] You may only rebate up to 115% of the original amount.</message>
  <pasref> realex payments reference</pasref>
  <cvnresult>M</cvnresult>
  <batchid>batch id for this transaction (if any)</batchid>
  <sha1hash>7384ae67....ac7d7d</sha1hash>
  <md5hash>34e7....a77d</md5hash>
</response>"
    RESPONSE
  end

  def successful_store_customer_response
    <<-RESPONSE
<response timestamp="20151218014939">
  <merchantid>your merchant id</merchantid>
  <account>account to use</account>
  <orderid>order id from request</orderid>
  <result>00</result>
  <message>Successful</message>
  <pasref>relaex payments reference</pasref>
  <authcode/>
  <batchid/>
  <timetaken>0</timetaken>
  <processingtimetaken/>
  <md5hash>742b8175....512ae8</md5hash>
  <sha1hash>ee69....e759</sha1hash>
</response>
    RESPONSE
  end

  def unsuccessful_store_customer_response
    <<-RESPONSE
<response timestamp="20151218024741">
  <merchantid>your merchant id</merchantid>
  <account>account to use</account>
  <orderid>order id from request</orderid>
  <result>506</result>
  <message>payerRef : must match "[a-zA-Z0-9_\-\. ]*"</message>
</response>
    RESPONSE
  end

  def successful_store_card_response
    <<-RESPONSE
<response timestamp=\"20151218014941\">
  <merchantid>your merchant id</merchantid>
  <account>account to use</account>
  <orderid>order id from request</orderid>
  <result>00</result>
  <message>Successful</message>
  <pasref>relaex payments reference</pasref>
  <authcode/>
  <batchid/>
  <timetaken>0</timetaken>
  <processingtimetaken/>
  <md5hash>de20....9738</md5hash>
  <sha1hash>50f27....5155</sha1hash>
</response>
    RESPONSE
  end

  def transcript
    <<-REQUEST
    <request timestamp="20150722170750" type="auth">
      <merchantid>your merchant id</merchantid>
      <orderid>445472dc5ea848fec1c1720a07d5710b</orderid>
      <amount currency="EUR">10000</amount>
      <card>
        <number>4000126842489127</number>
        <expdate>0620</expdate>
        <chname>Longbob Longsen</chname>
        <type>VISA</type>
        <issueno/>
        <cvn>
          <number>123</number>
          <presind>1</presind>
        </cvn>
      </card>
      <autosettle flag="1"/>
      <sha1hash>d22109765de91b75e7ad2e5d2fcf8a88235019d9</sha1hash>
      <comments>
        <comment id="1">Test Realex Purchase</comment>
      </comments>
      <tssinfo>
        <address type="billing">
          <code>90210</code>
          <country>US</country>
        </address>
      </tssinfo>
    </request>
    REQUEST
  end

  def scrubbed_transcript
    <<-REQUEST
    <request timestamp="20150722170750" type="auth">
      <merchantid>your merchant id</merchantid>
      <orderid>445472dc5ea848fec1c1720a07d5710b</orderid>
      <amount currency="EUR">10000</amount>
      <card>
        <number>[FILTERED]</number>
        <expdate>0620</expdate>
        <chname>Longbob Longsen</chname>
        <type>VISA</type>
        <issueno/>
        <cvn>
          <number>[FILTERED]</number>
          <presind>1</presind>
        </cvn>
      </card>
      <autosettle flag="1"/>
      <sha1hash>d22109765de91b75e7ad2e5d2fcf8a88235019d9</sha1hash>
      <comments>
        <comment id="1">Test Realex Purchase</comment>
      </comments>
      <tssinfo>
        <address type="billing">
          <code>90210</code>
          <country>US</country>
        </address>
      </tssinfo>
    </request>
  REQUEST
  end

  require 'nokogiri'
  def assert_xml_equal(expected, actual)
    assert_xml_equal_recursive(Nokogiri::XML(expected).root, Nokogiri::XML(actual).root)
  end

  def assert_xml_equal_recursive(a, b)
    assert_equal(a.name, b.name)
    assert_equal(a.text, b.text)
    a.attributes.zip(b.attributes).each do |(_, a1), (_, b1)|
      assert_equal a1.name, b1.name
      assert_equal a1.value, b1.value
    end
    a.children.zip(b.children).all?{|a1, b1| assert_xml_equal_recursive(a1, b1)}
  end
end
