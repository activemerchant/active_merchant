require 'test_helper'

class IatsPaymentsTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = IatsPaymentsGateway.new(
      :agent_code => 'login',
      :password => 'password',
      :region => 'uk'
    )
    @amount = 100
    @credit_card = credit_card
    @options = {
      :ip => '71.65.249.145',
      :order_id => generate_unique_id,
      :billing_address => address,
      :description => 'Store purchase'
    }
  end

  def test_successful_purchase
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |endpoint, data, headers|
      assert_match(/<agentCode>login<\/agentCode>/, data)
      assert_match(/<password>password<\/password>/, data)
      assert_match(/<customerIPAddress>#{@options[:ip]}<\/customerIPAddress>/, data)
      assert_match(/<invoiceNum>#{@options[:order_id]}<\/invoiceNum>/, data)
      assert_match(/<creditCardNum>#{@credit_card.number}<\/creditCardNum>/, data)
      assert_match(/<creditCardExpiry>0#{@credit_card.month}\/#{@credit_card.year.to_s[-2..-1]}<\/creditCardExpiry>/, data)
      assert_match(/<cvv2>#{@credit_card.verification_value}<\/cvv2>/, data)
      assert_match(/<mop>VISA<\/mop>/, data)
      assert_match(/<firstName>#{@credit_card.first_name}<\/firstName>/, data)
      assert_match(/<lastName>#{@credit_card.last_name}<\/lastName>/, data)
      assert_match(/<address>#{@options[:billing_address][:address1]}<\/address>/, data)
      assert_match(/<city>#{@options[:billing_address][:city]}<\/city>/, data)
      assert_match(/<state>#{@options[:billing_address][:state]}<\/state>/, data)
      assert_match(/<zipCode>#{@options[:billing_address][:zip]}<\/zipCode>/, data)
      assert_match(/<total>1.00<\/total>/, data)
      assert_match(/<comment>#{@options[:description]}<\/comment>/, data)
      assert_equal endpoint, 'https://www.uk.iatspayments.com/NetGate/ProcessLink.asmx?op=ProcessCreditCardV1'
      assert_equal headers['Content-Type'], 'application/soap+xml; charset=utf-8'
    end.respond_with(successful_purchase_response)

    assert response
    assert_instance_of Response, response
    assert_success response
    assert_equal 'A6DE6F24', response.authorization
    assert_equal 'Success', response.message
  end

  def test_failed_purchase
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.respond_with(failed_purchase_response)

    assert response
    assert_failure response
    assert_equal 'A6DE6F24', response.authorization
    assert response.message.include?('REJECT')
  end

  def test_successful_refund
    response = stub_comms do
      @gateway.refund(@amount, '1234', @options)
    end.check_request do |endpoint, data, headers|
      assert_match(/<transactionId>1234<\/transactionId>/, data)
      assert_match(/<total>-1.00<\/total>/, data)
    end.respond_with(successful_refund_response)

    assert response
    assert_success response
    assert_equal 'A6DEA654', response.authorization
  end

  def test_failed_refund
    response = stub_comms do
      @gateway.refund(@amount, '1234', @options)
    end.check_request do |endpoint, data, headers|
      assert_match(/<transactionId>1234<\/transactionId>/, data)
      assert_match(/<total>-1.00<\/total>/, data)
    end.respond_with(failed_refund_response)

    assert response
    assert_failure response
    assert_equal 'A6DEA654', response.authorization
  end

  def test_successful_store
    response = stub_comms do
      @gateway.store(@credit_card, @options)
    end.check_request do |endpoint, data, headers|
      assert_match(/beginDate/, data)
      assert_match(/endDate/, data)
      assert_match(%r{<creditCardNum>#{@credit_card.number}</creditCardNum>}, data)
      assert_match(%r{<amount>0</amount>}, data)
      assert_match(%r{<recurring>false</recurring>}, data)
    end.respond_with(successful_store_response)

    assert response
    assert_success response
    assert_equal 'A12181132', response.authorization
    assert_equal 'Success', response.message
  end

  def test_failed_store
    response = stub_comms do
      @gateway.store(@credit_card, @options)
    end.respond_with(failed_store_response)

    assert response
    assert_failure response
    assert_match /Invalid credit card number/, response.message
  end

  def test_successful_unstore
    response = stub_comms do
      @gateway.unstore("TheAuthorization", @options)
    end.check_request do |endpoint, data, headers|
      assert_match(%r{<customerCode>TheAuthorization</customerCode>}, data)
    end.respond_with(successful_unstore_response)

    assert response
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_deprecated_options
    assert_deprecation_warning("The 'login' option is deprecated in favor of 'agent_code' and will be removed in a future version.") do
      @gateway = IatsPaymentsGateway.new(
        :login => 'login',
        :password => 'password'
      )
    end

    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |endpoint, data, headers|
      assert_match(/<agentCode>login<\/agentCode>/, data)
      assert_match(/<password>password<\/password>/, data)
      assert_equal endpoint, 'https://www.iatspayments.com/NetGate/ProcessLink.asmx?op=ProcessCreditCardV1'
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_region_urls
    @gateway = IatsPaymentsGateway.new(
      :agent_code => 'code',
      :password => 'password',
      :region => 'na' #North america
    )

    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |endpoint, data, headers|
      assert_equal endpoint, 'https://www.iatspayments.com/NetGate/ProcessLink.asmx?op=ProcessCreditCardV1'
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_supported_countries
    @gateway.supported_countries.each do |country_code|
      assert ActiveMerchant::Country.find(country_code), "Supported country code #{country_code} is invalid. Please use a value explicitly listed in active_utils' ActiveMerchant::Country class."
    end
  end

  private

  def successful_purchase_response
    <<-XML
<?xml version="1.0" encoding="utf-8"?>
<soap12:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap12="http://www.w3.org/2003/05/soap-envelope">
  <soap12:Body>
    <ProcessCreditCardV1Response xmlns="https://www.iatspayments.com/NetGate/">
      <ProcessCreditCardV1Result>
        <IATSRESPONSE>
          <STATUS>Success</STATUS>
          <ERRORS />
          <PROCESSRESULT>
            <AUTHORIZATIONRESULT> OK</AUTHORIZATIONRESULT>
            <CUSTOMERCODE />
            <SETTLEMENTBATCHDATE> 04/22/2014</SETTLEMENTBATCHDATE>
            <SETTLEMENTDATE> 04/23/2014</SETTLEMENTDATE>
            <TRANSACTIONID>A6DE6F24</TRANSACTIONID>
          </PROCESSRESULT>
        </IATSRESPONSE>
      </ProcessCreditCardV1Result>
    </ProcessCreditCardV1Response>
  </soap12:Body>
</soap12:Envelope>
    XML
  end

  def failed_purchase_response
    <<-XML
<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <soap:Body>
    <ProcessCreditCardV1Response xmlns="https://www.iatspayments.com/NetGate/">
      <ProcessCreditCardV1Result>
        <IATSRESPONSE xmlns="">
          <STATUS>Success</STATUS>
          <ERRORS />
          <PROCESSRESULT>
            <AUTHORIZATIONRESULT> REJECT: 15</AUTHORIZATIONRESULT>
            <CUSTOMERCODE />
            <SETTLEMENTBATCHDATE> 04/22/2014</SETTLEMENTBATCHDATE>
            <SETTLEMENTDATE> 04/23/2014</SETTLEMENTDATE>
            <TRANSACTIONID>A6DE6F24</TRANSACTIONID>
          </PROCESSRESULT>
        </IATSRESPONSE>
      </ProcessCreditCardV1Result>
    </ProcessCreditCardV1Response>
  </soap:Body>
</soap:Envelope>
    XML
  end

  def successful_refund_response
    <<-XML
<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <soap:Body>
    <ProcessCreditCardV1Response xmlns="https://www.iatspayments.com/NetGate/">
      <ProcessCreditCardV1Result>
        <IATSRESPONSE xmlns="">
          <STATUS>Success</STATUS>
          <ERRORS />
          <PROCESSRESULT>
            <AUTHORIZATIONRESULT> OK: 678594: </AUTHORIZATIONRESULT>
            <CUSTOMERCODE />
            <SETTLEMENTBATCHDATE> 04/22/2014 </SETTLEMENTBATCHDATE>
            <SETTLEMENTDATE> 04/23/2014 </SETTLEMENTDATE>
            <TRANSACTIONID>A6DEA654</TRANSACTIONID>
          </PROCESSRESULT>
        </IATSRESPONSE>
      </ProcessCreditCardV1Result>
    </ProcessCreditCardV1Response>
  </soap:Body>
</soap:Envelope>
    XML
  end

  def failed_refund_response
    <<-XML
<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <soap:Body>
    <ProcessCreditCardV1Response xmlns="https://www.iatspayments.com/NetGate/">
      <ProcessCreditCardV1Result>
        <IATSRESPONSE xmlns="">
          <STATUS>Success</STATUS>
          <ERRORS />
          <PROCESSRESULT>
            <AUTHORIZATIONRESULT> REJECT: 15 </AUTHORIZATIONRESULT>
            <CUSTOMERCODE />
            <SETTLEMENTBATCHDATE> 04/22/2014 </SETTLEMENTBATCHDATE>
            <SETTLEMENTDATE> 04/23/2014 </SETTLEMENTDATE>
            <TRANSACTIONID>A6DEA654</TRANSACTIONID>
          </PROCESSRESULT>
        </IATSRESPONSE>
      </ProcessCreditCardV1Result>
    </ProcessCreditCardV1Response>
  </soap:Body>
</soap:Envelope>
    XML
  end

  def successful_store_response
    <<-XML
      <?xml version="1.0" encoding="UTF-8"?>
      <soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
        <soap:Body>
          <CreateCreditCardCustomerCodeV1Response xmlns="https://www.iatspayments.com/NetGate/">
            <CreateCreditCardCustomerCodeV1Result>
              <IATSRESPONSE xmlns="">
                <STATUS>Success</STATUS>
                <ERRORS />
                <PROCESSRESULT>
                  <AUTHORIZATIONRESULT>OK</AUTHORIZATIONRESULT>
                  <CUSTOMERCODE>A12181132</CUSTOMERCODE>
                </PROCESSRESULT>
              </IATSRESPONSE>
            </CreateCreditCardCustomerCodeV1Result>
          </CreateCreditCardCustomerCodeV1Response>
        </soap:Body>
      </soap:Envelope>
    XML
  end

  def failed_store_response
    <<-XML
      <?xml version="1.0" encoding="UTF-8"?>
      <soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
        <soap:Body>
          <CreateCreditCardCustomerCodeV1Response xmlns="https://www.iatspayments.com/NetGate/">
            <CreateCreditCardCustomerCodeV1Result>
              <IATSRESPONSE xmlns="">
                <STATUS>Success</STATUS>
                <ERRORS />
                <PROCESSRESULT>
                  <AUTHORIZATIONRESULT>0Error:Invalid credit card number</AUTHORIZATIONRESULT>
                  <CUSTOMERCODE />
                </PROCESSRESULT>
              </IATSRESPONSE>
            </CreateCreditCardCustomerCodeV1Result>
          </CreateCreditCardCustomerCodeV1Response>
        </soap:Body>
      </soap:Envelope>
    XML
  end

  def successful_unstore_response
    <<-XML
      <?xml version="1.0" encoding="UTF-8"?>
      <soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
        <soap:Body>
          <DeleteCustomerCodeV1Response xmlns="https://www.iatspayments.com/NetGate/">
            <DeleteCustomerCodeV1Result>
              <IATSRESPONSE xmlns="">
                <STATUS>Success</STATUS>
                <ERRORS />
                <PROCESSRESULT>
                  <AUTHORIZATIONRESULT>OK</AUTHORIZATIONRESULT>
                  <CUSTOMERCODE>"A12181132" is deleted</CUSTOMERCODE>
                </PROCESSRESULT>
              </IATSRESPONSE>
            </DeleteCustomerCodeV1Result>
          </DeleteCustomerCodeV1Response>
        </soap:Body>
      </soap:Envelope>
    XML
  end
end
