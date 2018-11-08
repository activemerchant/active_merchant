require 'test_helper'
require 'nokogiri'

class ActiveMerchant::Billing::OptimalPaymentGateway
  public :cc_auth_request
end

class OptimalPaymentTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = OptimalPaymentGateway.new(
      :account_number => '12345678',
      :store_id => 'login',
      :password => 'password'
    )

    @credit_card = credit_card
    @amount = 100

    @options = {
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase',
      :email => 'email@example.com'
    }
  end

  def test_full_request
    @gateway.instance_variable_set('@credit_card', @credit_card)
    assert_match full_request, @gateway.cc_auth_request(@amount, @options)
  end

  def test_ip_address_is_passed
    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(ip: '1.2.3.4'))
    end.check_request do |endpoint, data, headers|
      assert_match %r{customerIP%3E1.2.3.4%3C}, data
    end.respond_with(successful_purchase_response)
  end

  def test_minimal_request
    options = {
      :order_id => '1',
      :description => 'Store Purchase',
      :billing_address => {
        :zip      => 'K1C2N6',
      }
    }
    credit_card = CreditCard.new(
      :number => '4242424242424242',
      :month => 9,
      :year => Time.now.year + 1,
      :first_name => 'Longbob',
      :last_name => 'Longsen',
      :brand => 'visa'
    )
    @gateway.instance_variable_set('@credit_card', credit_card)
    assert_match minimal_request, @gateway.cc_auth_request(@amount, options)
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    # Replace with authorization number from the successful response
    assert_equal '126740505', response.authorization
    assert response.test?
  end

  def test_purchase_from_canada_includes_state_field
    @options[:billing_address][:country] = 'CA'
    @gateway.expects(:ssl_post).with do |url, data|
      data =~ /state/ && data !~ /region/
    end.returns(successful_purchase_response)

    assert @gateway.purchase(@amount, @credit_card, @options)
  end

  def test_purchase_from_us_includes_state_field
    @options[:billing_address][:country] = 'US'
    @gateway.expects(:ssl_post).with do |url, data|
      data =~ /state/ && data !~ /region/
    end.returns(successful_purchase_response)

    assert @gateway.purchase(@amount, @credit_card, @options)
  end

  def test_purchase_from_any_other_country_includes_region_field
    @options[:billing_address][:country] = 'GB'
    @gateway.expects(:ssl_post).with do |url, data|
      data =~ /region/ && data !~ /state/
    end.returns(successful_purchase_response)

    assert @gateway.purchase(@amount, @credit_card, @options)
  end

  def test_purchase_with_shipping_address
    @options[:shipping_address] = {:country => 'CA'}
    @gateway.expects(:ssl_post).with do |url, data|
      xml = data.split('&').detect{|string| string =~ /txnRequest=/}.gsub('txnRequest=', '')
      doc = Nokogiri::XML.parse(CGI.unescape(xml))
      doc.xpath('//xmlns:shippingDetails/xmlns:country').first.text == 'CA' && doc.to_s.include?('<shippingDetails>')
    end.returns(successful_purchase_response)

    assert @gateway.purchase(@amount, @credit_card, @options)
  end

  def test_purchase_without_shipping_address
    @options[:shipping_address] = nil
    @gateway.expects(:ssl_post).with do |url, data|
      xml = data.split('&').detect{|string| string =~ /txnRequest=/}.gsub('txnRequest=', '')
      doc = Nokogiri::XML.parse(CGI.unescape(xml))
      doc.to_s.include?('<shippingDetails>') == false
    end.returns(successful_purchase_response)

    assert @gateway.purchase(@amount, @credit_card, @options)
  end

  def test_purchase_without_billing_address
    @options[:billing_address] = nil
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
  end

  def test_cvd_fields_pass_correctly
    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |endpoint, data, headers|
      assert_match(/cvdIndicator%3E1%3C\/cvdIndicator%3E%0A%20%20%20%20%3Ccvd%3E123%3C\/cvd/, data)
    end.respond_with(successful_purchase_response)

    credit_card = CreditCard.new(
      :number => '4242424242424242',
      :month => 9,
      :year => Time.now.year + 1,
      :first_name => 'Longbob',
      :last_name => 'Longsen',
      :brand => 'visa'
    )

    stub_comms do
      @gateway.purchase(@amount, credit_card, @options)
    end.check_request do |endpoint, data, headers|
      assert_match(/cvdIndicator%3E0%3C\/cvdIndicator%3E%0A%20%20%3C\/card/, data)
    end.respond_with(failed_purchase_response)
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.void('1234567', @options)
    assert_instance_of Response, response
    assert_success response

    # Replace with authorization number from the successful response
    assert_equal '126740505', response.authorization
    assert response.test?
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_in_production_with_test_param_sends_request_to_test_server
    ActiveMerchant::Billing::Base.mode = :production
    @gateway = OptimalPaymentGateway.new(
      :account_number => '12345678',
      :store_id => 'login',
      :password => 'password',
      :test => true
    )
    @gateway.expects(:ssl_post).with('https://webservices.test.optimalpayments.com/creditcardWS/CreditCardServlet/v1', anything).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    assert response.test?
  ensure
    ActiveMerchant::Billing::Base.mode = :test
  end

  def test_avs_result_in_response
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert response.avs_result['code']
  end

  def test_cvv_result_in_response
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert response.cvv_result['code']
  end

  def test_avs_results_not_in_response
    @gateway.expects(:ssl_post).returns(successful_purchase_response_without_avs_results)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert !response.avs_result['code']
    assert !response.cvv_result['code']
  end

  def test_deprecated_options
    assert_deprecation_warning("The 'account' option is deprecated in favor of 'account_number' and will be removed in a future version.") do
      @gateway = OptimalPaymentGateway.new(
        :account => '12345678',
        :store_id => 'login',
        :password => 'password'
      )
    end

    assert_deprecation_warning("The 'login' option is deprecated in favor of 'store_id' and will be removed in a future version.") do
      @gateway = OptimalPaymentGateway.new(
        :account_number => '12345678',
        :login => 'login',
        :password => 'password'
      )
    end
  end

  def test_scrub
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
    assert_equal @gateway.scrub(pre_scrubbed_double_escaped), post_scrubbed_double_escaped
  end

  private

  def full_request
    str = <<-XML
<ccAuthRequestV1 xmlns>
  <merchantAccount>
    <accountNum>12345678</accountNum>
    <storeID>login</storeID>
    <storePwd>password</storePwd>
  </merchantAccount>
  <merchantRefNum>1</merchantRefNum>
  <amount>1.0</amount>
  <card>
    <cardNum>4242424242424242</cardNum>
    <cardExpiry>
      <month>9</month>
      <year>#{Time.now.year + 1}</year>
    </cardExpiry>
    <cardType>VI</cardType>
    <cvdIndicator>1</cvdIndicator>
    <cvd>123</cvd>
  </card>
  <billingDetails>
    <cardPayMethod>WEB</cardPayMethod>
    <firstName>Jim</firstName>
    <lastName>Smith</lastName>
    <street>456 My Street</street>
    <street2>Apt 1</street2>
    <city>Ottawa</city>
    <state>ON</state>
    <country>CA</country>
    <zip>K1C2N6</zip>
    <phone>(555)555-5555</phone>
    <email>email@example.com</email>
  </billingDetails>
</ccAuthRequestV1>
    XML
    Regexp.new(Regexp.escape(str).sub('xmlns', '[^>]+').sub('/>', '(/>|></[^>]+>)'))
  end

  def minimal_request
    str = <<-XML
<ccAuthRequestV1 xmlns>
  <merchantAccount>
    <accountNum>12345678</accountNum>
    <storeID>login</storeID>
    <storePwd>password</storePwd>
  </merchantAccount>
  <merchantRefNum>1</merchantRefNum>
  <amount>1.0</amount>
  <card>
    <cardNum>4242424242424242</cardNum>
    <cardExpiry>
      <month>9</month>
      <year>#{Time.now.year + 1}</year>
    </cardExpiry>
    <cardType>VI</cardType>
    <cvdIndicator>0</cvdIndicator>
  </card>
  <billingDetails>
    <cardPayMethod>WEB</cardPayMethod>
    <zip>K1C2N6</zip>
  </billingDetails>
</ccAuthRequestV1>
    XML
    Regexp.new(Regexp.escape(str).sub('xmlns', '[^>]+').sub('/>', '(/>|></[^>]+>)'))
  end

  # Place raw successful response from gateway here
  def successful_purchase_response
    <<-XML
<ccTxnResponseV1 xmlns="http://www.optimalpayments.com/creditcard/xmlschema/v1">
  <confirmationNumber>126740505</confirmationNumber>
  <decision>ACCEPTED</decision>
  <code>0</code>
  <description>No Error</description>
  <authCode>112232</authCode>
  <avsResponse>B</avsResponse>
  <cvdResponse>M</cvdResponse>
  <detail>
    <tag>InternalResponseCode</tag>
    <value>0</value>
  </detail>
  <detail>
    <tag>SubErrorCode</tag>
    <value>0</value>
  </detail>
  <detail>
    <tag>InternalResponseDescription</tag>
    <value>no_error</value>
  </detail>
  <txnTime>2009-01-08T17:00:45.210-05:00</txnTime>
  <duplicateFound>false</duplicateFound>
</ccTxnResponseV1>
    XML
  end

  # Place raw successful response from gateway here
  def successful_purchase_response_without_avs_results
    <<-XML
<ccTxnResponseV1 xmlns="http://www.optimalpayments.com/creditcard/xmlschema/v1">
  <confirmationNumber>126740505</confirmationNumber>
  <decision>ACCEPTED</decision>
  <code>0</code>
  <description>No Error</description>
  <authCode>112232</authCode>
  <detail>
    <tag>InternalResponseCode</tag>
    <value>0</value>
  </detail>
  <detail>
    <tag>SubErrorCode</tag>
    <value>0</value>
  </detail>
  <detail>
    <tag>InternalResponseDescription</tag>
    <value>no_error</value>
  </detail>
  <txnTime>2009-01-08T17:00:45.210-05:00</txnTime>
  <duplicateFound>false</duplicateFound>
</ccTxnResponseV1>
    XML
  end

  # Place raw failed response from gateway here
  def failed_purchase_response
    <<-XML
<ccTxnResponseV1 xmlns="http://www.optimalpayments.com/creditcard/xmlschema/v1">
  <confirmationNumber>126740506</confirmationNumber>
  <decision>DECLINED</decision>
  <code>3009</code>
  <actionCode>D</actionCode>
  <description>Your request has been declined by the issuing bank.</description>
  <avsResponse>B</avsResponse>
  <cvdResponse>M</cvdResponse>
  <detail>
    <tag>InternalResponseCode</tag>
    <value>160</value>
  </detail>
  <detail>
    <tag>SubErrorCode</tag>
    <value>1005</value>
  </detail>
  <detail>
    <tag>InternalResponseDescription</tag>
    <value>auth declined</value>
  </detail>
  <txnTime>2009-01-08T17:00:46.529-05:00</txnTime>
  <duplicateFound>false</duplicateFound>
</ccTxnResponseV1>
    XML
  end

  def pre_scrubbed
    <<-EOS
opening connection to webservices.test.optimalpayments.com:443...
opened
starting SSL for webservices.test.optimalpayments.com:443...
SSL established
<- "POST /creditcardWS/CreditCardServlet/v1 HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: webservices.test.optimalpayments.com\r\nContent-Length: 1616\r\n\r\n"
<- "txnMode=ccPurchase&txnRequest=%3CccAuthRequestV1%20xmlns=%22http://www.optimalpayments.com/creditcard/xmlschema/v1%22%20xmlns:xsi=%22http://www.w3.org/2001/XMLSchema-instance%22%20xsi:schemaLocation=%22http://www.optimalpayments.com/creditcard/xmlschema/v1%22%3E%0A%20%20%3CmerchantAccount%3E%0A%20%20%20%20%3CaccountNum%3E1001134550%3C/accountNum%3E%0A%20%20%20%20%3CstoreID%3Etest%3C/storeID%3E%0A%20%20%20%20%3CstorePwd%3Etest%3C/storePwd%3E%0A%20%20%3C/merchantAccount%3E%0A%20%20%3CmerchantRefNum%3E1%3C/merchantRefNum%3E%0A%20%20%3Camount%3E1.0%3C/amount%3E%0A%20%20%3Ccard%3E%0A%20%20%20%20%3CcardNum%3E4387751111011%3C/cardNum%3E%0A%20%20%20%20%3CcardExpiry%3E%0A%20%20%20%20%20%20%3Cmonth%3E9%3C/month%3E%0A%20%20%20%20%20%20%3Cyear%3E2019%3C/year%3E%0A%20%20%20%20%3C/cardExpiry%3E%0A%20%20%20%20%3CcardType%3EVI%3C/cardType%3E%0A%20%20%20%20%3CcvdIndicator%3E1%3C/cvdIndicator%3E%0A%20%20%20%20%3Ccvd%3E123%3C/cvd%3E%0A%20%20%3C/card%3E%0A%20%20%3CbillingDetails%3E%0A%20%20%20%20%3CcardPayMethod%3EWEB%3C/cardPayMethod%3E%0A%20%20%20%20%3CfirstName%3EJim%3C/firstName%3E%0A%20%20%20%20%3ClastName%3ESmith%3C/lastName%3E%0A%20%20%20%20%3Cstreet%3E456%20My%20Street%3C/street%3E%0A%20%20%20%20%3Cstreet2%3EApt%201%3C/street2%3E%0A%20%20%20%20%3Ccity%3EOttawa%3C/city%3E%0A%20%20%20%20%3Cstate%3EON%3C/state%3E%0A%20%20%20%20%3Ccountry%3ECA%3C/country%3E%0A%20%20%20%20%3Czip%3EK1C2N6%3C/zip%3E%0A%20%20%20%20%3Cphone%3E(555)555-5555%3C/phone%3E%0A%20%20%20%20%3Cemail%3Eemail@example.com%3C/email%3E%0A%20%20%3C/billingDetails%3E%0A%20%20%3CcustomerIP%3E1.2.3.4%3C/customerIP%3E%0A%3C/ccAuthRequestV1%3E%0A"
-> "HTTP/1.1 200 OK\r\n"
-> "Server: WebServer32xS10i3\r\n"
-> "Content-Length: 632\r\n"
-> "X-ApplicationUid: GUID=610a301289c34e8254330b7edc724f5b\r\n"
-> "Content-Type: application/xml\r\n"
-> "Date: Mon, 12 Feb 2018 21:57:42 GMT\r\n"
-> "Connection: close\r\n"
-> "\r\n"
reading 632 bytes...
-> "<"
-> "?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<ccTxnResponseV1 xmlns=\"http://www.optimalpayments.com/creditcard/xmlschema/v1\"><confirmationNumber>498871860</confirmationNumber><decision>ACCEPTED</decision><code>0</code><description>No Error</description><authCode>369231</authCode><avsResponse>X</avsResponse><cvdResponse>M</cvdResponse><detail><tag>InternalResponseCode</tag><value>0</value></detail><detail><tag>SubErrorCode</tag><value>0</value></detail><detail><tag>InternalResponseDescription</tag><value>no_error</value></detail><txnTime>2018-02-12T16:57:42.289-05:00</txnTime><duplicateFound>false</duplicateFound></ccTxnResponseV1>"
read 632 bytes
Conn close
    EOS
  end

  def post_scrubbed
    <<-EOS
opening connection to webservices.test.optimalpayments.com:443...
opened
starting SSL for webservices.test.optimalpayments.com:443...
SSL established
<- "POST /creditcardWS/CreditCardServlet/v1 HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: webservices.test.optimalpayments.com\r\nContent-Length: 1616\r\n\r\n"
<- "txnMode=ccPurchase&txnRequest=%3CccAuthRequestV1%20xmlns=%22http://www.optimalpayments.com/creditcard/xmlschema/v1%22%20xmlns:xsi=%22http://www.w3.org/2001/XMLSchema-instance%22%20xsi:schemaLocation=%22http://www.optimalpayments.com/creditcard/xmlschema/v1%22%3E%0A%20%20%3CmerchantAccount%3E%0A%20%20%20%20%3CaccountNum%3E1001134550%3C/accountNum%3E%0A%20%20%20%20%3CstoreID%3Etest%3C/storeID%3E%0A%20%20%20%20%3CstorePwd%3E[FILTERED]%3C/storePwd%3E%0A%20%20%3C/merchantAccount%3E%0A%20%20%3CmerchantRefNum%3E1%3C/merchantRefNum%3E%0A%20%20%3Camount%3E1.0%3C/amount%3E%0A%20%20%3Ccard%3E%0A%20%20%20%20%3CcardNum%3E[FILTERED]%3C/cardNum%3E%0A%20%20%20%20%3CcardExpiry%3E%0A%20%20%20%20%20%20%3Cmonth%3E9%3C/month%3E%0A%20%20%20%20%20%20%3Cyear%3E2019%3C/year%3E%0A%20%20%20%20%3C/cardExpiry%3E%0A%20%20%20%20%3CcardType%3EVI%3C/cardType%3E%0A%20%20%20%20%3CcvdIndicator%3E1%3C/cvdIndicator%3E%0A%20%20%20%20%3Ccvd%3E[FILTERED]%3C/cvd%3E%0A%20%20%3C/card%3E%0A%20%20%3CbillingDetails%3E%0A%20%20%20%20%3CcardPayMethod%3EWEB%3C/cardPayMethod%3E%0A%20%20%20%20%3CfirstName%3EJim%3C/firstName%3E%0A%20%20%20%20%3ClastName%3ESmith%3C/lastName%3E%0A%20%20%20%20%3Cstreet%3E456%20My%20Street%3C/street%3E%0A%20%20%20%20%3Cstreet2%3EApt%201%3C/street2%3E%0A%20%20%20%20%3Ccity%3EOttawa%3C/city%3E%0A%20%20%20%20%3Cstate%3EON%3C/state%3E%0A%20%20%20%20%3Ccountry%3ECA%3C/country%3E%0A%20%20%20%20%3Czip%3EK1C2N6%3C/zip%3E%0A%20%20%20%20%3Cphone%3E(555)555-5555%3C/phone%3E%0A%20%20%20%20%3Cemail%3Eemail@example.com%3C/email%3E%0A%20%20%3C/billingDetails%3E%0A%20%20%3CcustomerIP%3E1.2.3.4%3C/customerIP%3E%0A%3C/ccAuthRequestV1%3E%0A"
-> "HTTP/1.1 200 OK\r\n"
-> "Server: WebServer32xS10i3\r\n"
-> "Content-Length: 632\r\n"
-> "X-ApplicationUid: GUID=610a301289c34e8254330b7edc724f5b\r\n"
-> "Content-Type: application/xml\r\n"
-> "Date: Mon, 12 Feb 2018 21:57:42 GMT\r\n"
-> "Connection: close\r\n"
-> "\r\n"
reading 632 bytes...
-> "<"
-> "?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<ccTxnResponseV1 xmlns=\"http://www.optimalpayments.com/creditcard/xmlschema/v1\"><confirmationNumber>498871860</confirmationNumber><decision>ACCEPTED</decision><code>0</code><description>No Error</description><authCode>369231</authCode><avsResponse>X</avsResponse><cvdResponse>M</cvdResponse><detail><tag>InternalResponseCode</tag><value>0</value></detail><detail><tag>SubErrorCode</tag><value>0</value></detail><detail><tag>InternalResponseDescription</tag><value>no_error</value></detail><txnTime>2018-02-12T16:57:42.289-05:00</txnTime><duplicateFound>false</duplicateFound></ccTxnResponseV1>"
read 632 bytes
Conn close
    EOS
  end

  def pre_scrubbed_double_escaped
    <<-PRE_SCRUBBED
      txnMode=ccPurchase&txnRequest=%3CccAuthRequestV1+xmlns%3D%22http%3A%2F%2Fwww.optimalpayments.com%2Fcreditcard%2Fxmlschema%2Fv1%22+xmlns%3Axsi%3D%22http%3A%2F%2Fwww.w3.org%2F2001%2FXMLSchema-instance%22+xsi%3AschemaLocation%3D%22http%3A%2F%2Fwww.optimalpayments.com%2Fcreditcard%2Fxmlschema%2Fv1%22%3E%0A++%3CmerchantAccount%3E%0A++++%3CaccountNum%3E89986098%3C%2FaccountNum%3E%0A++++%3CstoreID%3Etest%3C%2FstoreID%3E%0A++++%3CstorePwd%3Etest%3C%2FstorePwd%3E%0A++%3C%2FmerchantAccount%3E%0A++%3CmerchantRefNum%3E1%3C%2FmerchantRefNum%3E%0A++%3Camount%3E1.0%3C%2Famount%3E%0A++%3Ccard%3E%0A++++%3CcardNum%3E4387751111011%3C%2FcardNum%3E%0A++++%3CcardExpiry%3E%0A++++++%3Cmonth%3E9%3C%2Fmonth%3E%0A++++++%3Cyear%3E2015%3C%2Fyear%3E%0A++++%3C%2FcardExpiry%3E%0A++++%3CcardType%3EVI%3C%2FcardType%3E%0A++++%3CcvdIndicator%3E1%3C%2FcvdIndicator%3E%0A++++%3Ccvd%3E123%3C%2Fcvd%3E%0A++%3C%2Fcard%3E%0A++%3CbillingDetails%3E%0A++++%3CcardPayMethod%3EWEB%3C%2FcardPayMethod%3E%0A++++%3CfirstName%3EJim%3C%2FfirstName%3E%0A++++%3ClastName%3ESmith%3C%2FlastName%3E%0A++++%3Cstreet%3E1234+My+Street%3C%2Fstreet%3E%0A++++%3Cstreet2%3EApt+1%3C%2Fstreet2%3E%0A++++%3Ccity%3EOttawa%3C%2Fcity%3E%0A++++%3Cstate%3EON%3C%2Fstate%3E%0A++++%3Ccountry%3ECA%3C%2Fcountry%3E%0A++++%3Czip%3EK1C2N6%3C%2Fzip%3E%0A++++%3Cphone%3E%28555%29555-5555%3C%2Fphone%3E%0A++++%3Cemail%3Eemail%40example.com%3C%2Femail%3E%0A++%3C%2FbillingDetails%3E%0A++%3CcustomerIP%3E1.2.3.4%3C%2FcustomerIP%3E%0A%3C%2FccAuthRequestV1%3E%0A
    PRE_SCRUBBED
  end

  def post_scrubbed_double_escaped
    <<-POST_SCRUBBED
      txnMode=ccPurchase&txnRequest=%3CccAuthRequestV1+xmlns%3D%22http%3A%2F%2Fwww.optimalpayments.com%2Fcreditcard%2Fxmlschema%2Fv1%22+xmlns%3Axsi%3D%22http%3A%2F%2Fwww.w3.org%2F2001%2FXMLSchema-instance%22+xsi%3AschemaLocation%3D%22http%3A%2F%2Fwww.optimalpayments.com%2Fcreditcard%2Fxmlschema%2Fv1%22%3E%0A++%3CmerchantAccount%3E%0A++++%3CaccountNum%3E89986098%3C%2FaccountNum%3E%0A++++%3CstoreID%3Etest%3C%2FstoreID%3E%0A++++%3CstorePwd%3E[FILTERED]%3C%2FstorePwd%3E%0A++%3C%2FmerchantAccount%3E%0A++%3CmerchantRefNum%3E1%3C%2FmerchantRefNum%3E%0A++%3Camount%3E1.0%3C%2Famount%3E%0A++%3Ccard%3E%0A++++%3CcardNum%3E[FILTERED]%3C%2FcardNum%3E%0A++++%3CcardExpiry%3E%0A++++++%3Cmonth%3E9%3C%2Fmonth%3E%0A++++++%3Cyear%3E2015%3C%2Fyear%3E%0A++++%3C%2FcardExpiry%3E%0A++++%3CcardType%3EVI%3C%2FcardType%3E%0A++++%3CcvdIndicator%3E1%3C%2FcvdIndicator%3E%0A++++%3Ccvd%3E[FILTERED]%3C%2Fcvd%3E%0A++%3C%2Fcard%3E%0A++%3CbillingDetails%3E%0A++++%3CcardPayMethod%3EWEB%3C%2FcardPayMethod%3E%0A++++%3CfirstName%3EJim%3C%2FfirstName%3E%0A++++%3ClastName%3ESmith%3C%2FlastName%3E%0A++++%3Cstreet%3E1234+My+Street%3C%2Fstreet%3E%0A++++%3Cstreet2%3EApt+1%3C%2Fstreet2%3E%0A++++%3Ccity%3EOttawa%3C%2Fcity%3E%0A++++%3Cstate%3EON%3C%2Fstate%3E%0A++++%3Ccountry%3ECA%3C%2Fcountry%3E%0A++++%3Czip%3EK1C2N6%3C%2Fzip%3E%0A++++%3Cphone%3E%28555%29555-5555%3C%2Fphone%3E%0A++++%3Cemail%3Eemail%40example.com%3C%2Femail%3E%0A++%3C%2FbillingDetails%3E%0A++%3CcustomerIP%3E1.2.3.4%3C%2FcustomerIP%3E%0A%3C%2FccAuthRequestV1%3E%0A
    POST_SCRUBBED
  end
end
