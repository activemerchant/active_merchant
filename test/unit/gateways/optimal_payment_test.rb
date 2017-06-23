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
      @gateway.purchase(@amount, @credit_card, @options.merge(ip: "1.2.3.4"))
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
    @options[:billing_address][:country] = "CA"
    @gateway.expects(:ssl_post).with do |url, data|
      data =~ /state/ && data !~ /region/
    end.returns(successful_purchase_response)

    assert @gateway.purchase(@amount, @credit_card, @options)
  end

  def test_purchase_from_us_includes_state_field
    @options[:billing_address][:country] = "US"
    @gateway.expects(:ssl_post).with do |url, data|
      data =~ /state/ && data !~ /region/
    end.returns(successful_purchase_response)

    assert @gateway.purchase(@amount, @credit_card, @options)
  end

  def test_purchase_from_any_other_country_includes_region_field
    @options[:billing_address][:country] = "GB"
    @gateway.expects(:ssl_post).with do |url, data|
      data =~ /region/ && data !~ /state/
    end.returns(successful_purchase_response)

    assert @gateway.purchase(@amount, @credit_card, @options)
  end

  def test_purchase_with_shipping_address
    @options[:shipping_address] = {:country => "CA"}
    @gateway.expects(:ssl_post).with do |url, data|
      xml = data.split("&").detect{|string| string =~ /txnRequest=/}.gsub("txnRequest=","")
      doc = Nokogiri::XML.parse(CGI.unescape(xml))
      doc.xpath('//xmlns:shippingDetails/xmlns:country').first.text == "CA" && doc.to_s.include?('<shippingDetails>')
    end.returns(successful_purchase_response)

    assert @gateway.purchase(@amount, @credit_card, @options)
  end

  def test_purchase_without_shipping_address
    @options[:shipping_address] = nil
    @gateway.expects(:ssl_post).with do |url, data|
      xml = data.split("&").detect{|string| string =~ /txnRequest=/}.gsub("txnRequest=","")
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
      assert_match (/cvdIndicator%3E1%3C\/cvdIndicator%3E%0A%20%20%20%20%3Ccvd%3E123%3C\/cvd/), data
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
      assert_match (/cvdIndicator%3E0%3C\/cvdIndicator%3E%0A%20%20%3C\/card/), data
    end.respond_with(failed_purchase_response)
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.void("1234567", @options)
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
    begin
      ActiveMerchant::Billing::Base.mode = :production
      @gateway = OptimalPaymentGateway.new(
                    :account_number => '12345678',
                   :store_id => 'login',
                   :password => 'password',
                   :test => true
                 )
      @gateway.expects(:ssl_post).with("https://webservices.test.optimalpayments.com/creditcardWS/CreditCardServlet/v1", anything).returns(successful_purchase_response)

      assert response = @gateway.purchase(@amount, @credit_card, @options)
      assert_instance_of Response, response
      assert_success response
      assert response.test?
    ensure
      ActiveMerchant::Billing::Base.mode = :test
    end
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
end
