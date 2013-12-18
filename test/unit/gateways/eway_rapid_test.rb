require "test_helper"

class EwayRapidTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = EwayRapidGateway.new(
      :login => "login",
      :password => "password"
    )

    @credit_card = credit_card
    @amount = 100
  end

  def test_purchase_calls_sub_methods
    request = sequence("request")
    @gateway.expects(:setup_purchase).with(@amount, {:order_id => 1, :redirect_url => "http://example.com/"}).returns(Response.new(true, "Success", {"formactionurl" => "url"}, :authorization => "auth1")).in_sequence(request)
    @gateway.expects(:run_purchase).with("auth1", @credit_card, "url").returns(Response.new(true, "Success", {}, :authorization => "auth2")).in_sequence(request)
    @gateway.expects(:status).with("auth2").returns(Response.new(true, "Success", {})).in_sequence(request)

    response = @gateway.purchase(@amount, @credit_card, :order_id => 1)
    assert_success response
  end

  def test_successful_setup_purchase
    response = stub_comms do
      @gateway.setup_purchase(@amount, :redirect_url => "http://bogus")
    end.respond_with(successful_setup_purchase_response)

    assert_success response
    assert_equal "Succeeded", response.message
    assert_equal(
      "60CF3xWrFUQeDCEsJcA8zNHaspAT3CKpe-0DiqWjTYA3RZw1xhw2LU-BFCNYbr7eJt8KFaxCxmzYh9WDAYX8yIuYexTq0tC8i2kOt0dm0EV-mjxYEQ2YeHP2dazkSc7j58OiT",
      response.authorization
    )
    assert_equal "https://secure-au.sandbox.ewaypayments.com/Process", response.form_url
    assert response.test?
  end

  def test_localized_currency
    stub_comms do
      @gateway.setup_purchase(100, :currency => 'CAD', :redirect_url => '')
    end.check_request do |endpoint, data, headers|
      assert_match /<TotalAmount>100<\/TotalAmount>/, data
    end.respond_with(successful_setup_purchase_response)

    stub_comms do
      @gateway.setup_purchase(100, :currency => 'JPY', :redirect_url => '')
    end.check_request do |endpoint, data, headers|
      assert_match /<TotalAmount>1<\/TotalAmount>/, data
    end.respond_with(successful_setup_purchase_response)
  end

  def test_failed_setup_purchase
    response = stub_comms do
      @gateway.setup_purchase(@amount, :redirect_url => "http://bogus")
    end.respond_with(failed_setup_purchase_response)

    assert_failure response
    assert_equal "RedirectURL Required", response.message
    assert_nil response.authorization
    assert response.test?
  end

  def test_setup_purchase_with_all_options
    response = stub_comms do
      @gateway.setup_purchase(200,
        :redirect_url => "http://awesomesauce.com",
        :ip => "0.0.0.0",
        :request_method => "CustomRequest",
        :application_id => "Woohoo",
        :description => "Description",
        :order_id => "orderid1",
        :currency => "INR",
        :email => "jim@example.com",
        :billing_address => {
          :title    => "Mr.",
          :name     => "Jim Awesome Smith",
          :company  => "Awesome Co",
          :address1 => "1234 My Street",
          :address2 => "Apt 1",
          :city     => "Ottawa",
          :state    => "ON",
          :zip      => "K1C2N6",
          :country  => "CA",
          :phone    => "(555)555-5555",
          :fax      => "(555)555-6666"
        },
        :shipping_address => {
          :title    => "Ms.",
          :name     => "Baker",
          :company  => "Elsewhere Inc.",
          :address1 => "4321 Their St.",
          :address2 => "Apt 2",
          :city     => "Chicago",
          :state    => "IL",
          :zip      => "60625",
          :country  => "US",
          :phone    => "1115555555",
          :fax      => "1115556666"
        }
      )
    end.check_request do |endpoint, data, headers|
      assert_no_match(%r{#{@credit_card.number}}, data)

      assert_match(%r{RedirectUrl>http://awesomesauce.com<}, data)
      assert_match(%r{CustomerIP>0.0.0.0<}, data)
      assert_match(%r{Method>CustomRequest<}, data)
      assert_match(%r{DeviceID>Woohoo<}, data)

      assert_match(%r{TotalAmount>200<}, data)
      assert_match(%r{InvoiceDescription>Description<}, data)
      assert_match(%r{InvoiceReference>orderid1<}, data)
      assert_match(%r{CurrencyCode>INR<}, data)

      assert_match(%r{Title>Mr.<}, data)
      assert_match(%r{FirstName>Jim<}, data)
      assert_match(%r{LastName>Awesome Smith<}, data)
      assert_match(%r{CompanyName>Awesome Co<}, data)
      assert_match(%r{Street1>1234 My Street<}, data)
      assert_match(%r{Street2>Apt 1<}, data)
      assert_match(%r{City>Ottawa<}, data)
      assert_match(%r{State>ON<}, data)
      assert_match(%r{PostalCode>K1C2N6<}, data)
      assert_match(%r{Country>ca<}, data)
      assert_match(%r{Phone>\(555\)555-5555<}, data)
      assert_match(%r{Fax>\(555\)555-6666<}, data)
      assert_match(%r{Email>jim@example\.com<}, data)

      assert_match(%r{Title>Ms.<}, data)
      assert_match(%r{LastName>Baker<}, data)
      assert_no_match(%r{Elsewhere Inc.}, data)
      assert_match(%r{Street1>4321 Their St.<}, data)
      assert_match(%r{Street2>Apt 2<}, data)
      assert_match(%r{City>Chicago<}, data)
      assert_match(%r{State>IL<}, data)
      assert_match(%r{PostalCode>60625<}, data)
      assert_match(%r{Country>us<}, data)
      assert_match(%r{Phone>1115555555<}, data)
      assert_match(%r{Fax>1115556666<}, data)
      assert_match(%r{Email>(\s+)?<}, data)
    end.respond_with(successful_setup_purchase_response)

    assert_success response
    assert_equal(
      "60CF3xWrFUQeDCEsJcA8zNHaspAT3CKpe-0DiqWjTYA3RZw1xhw2LU-BFCNYbr7eJt8KFaxCxmzYh9WDAYX8yIuYexTq0tC8i2kOt0dm0EV-mjxYEQ2YeHP2dazkSc7j58OiT",
      response.authorization
    )
    assert response.test?
  end

  def test_successful_run_purchase
    request_sequence = sequence("request")
    @gateway.expects(:ssl_request).returns(successful_setup_purchase_response).in_sequence(request_sequence)
    @gateway.expects(:raw_ssl_request).with(
      :post,
      "https://secure-au.sandbox.ewaypayments.com/Process",
      all_of(
        regexp_matches(%r{EWAY_ACCESSCODE=60CF3xWrFUQeDCEsJcA8zNHaspAT3CKpe-0DiqWjTYA3RZw1xhw2LU-BFCNYbr7eJt8KFaxCxmzYh9WDAYX8yIuYexTq0tC8i2kOt0dm0EV-mjxYEQ2YeHP2dazkSc7j58OiT}),
        regexp_matches(%r{EWAY_CARDNAME=Longbob\+Longsen}),
        regexp_matches(%r{EWAY_CARDNUMBER=#{@credit_card.number}}),
        regexp_matches(%r{EWAY_CARDEXPIRYMONTH=#{@credit_card.month}}),
        regexp_matches(%r{EWAY_CARDEXPIRYYEAR=#{@credit_card.year}}),
        regexp_matches(%r{EWAY_CARDCVN=#{@credit_card.verification_value}})
      ),
      anything
    ).returns(successful_run_purchase_response).in_sequence(request_sequence)
    @gateway.expects(:ssl_request).returns(successful_status_response).in_sequence(request_sequence)

    response = @gateway.purchase(@amount, @credit_card, :order_id => 1)
    assert_success response
    assert_equal "Transaction Approved", response.message
    assert_equal(
      "60CF3sfH7-yvAsUAHrdIiGppPrQW7v7DMAXxKkaKwyrIUoqvUvK44XbK9G9HNbngIz_iwQpfmPT_duMgh2G0pXCX8i4z1RAmMHpUQwa6VrghV3Bx9rh_tojjym7LC_fE-eR97",
      response.authorization
    )
    assert response.test?
  end

  def test_failed_run_purchase
    request_sequence = sequence("request")
    @gateway.expects(:ssl_request).returns(successful_setup_purchase_response).in_sequence(request_sequence)
    @gateway.expects(:raw_ssl_request).returns(failed_run_purchase_response).in_sequence(request_sequence)

    response = @gateway.purchase(@amount, @credit_card, :order_id => 1)
    assert_failure response
    assert_match %r{Not Found}, response.message
    assert_nil response.authorization
    assert response.test?
  end

  def test_successful_status
    response = stub_comms do
      @gateway.status("thetransauth")
    end.check_request do |endpoint, data, headers|
      assert_match(%r{thetransauth}, data)
    end.respond_with(successful_status_response)

    assert_success response
    assert_equal(
      "60CF3sfH7-yvAsUAHrdIiGppPrQW7v7DMAXxKkaKwyrIUoqvUvK44XbK9G9HNbngIz_iwQpfmPT_duMgh2G0pXCX8i4z1RAmMHpUQwa6VrghV3Bx9rh_tojjym7LC_fE-eR97",
      response.authorization
    )
    assert response.test?
    assert_equal "Transaction Approved", response.message
    assert_equal "orderid1", response.params["invoicereference"]
  end

  def test_failed_status
    response = stub_comms do
      @gateway.status("thetransauth")
    end.respond_with(failed_status_response)

    assert_failure response
    assert_equal(
      "A1001WfAHR_QP8daLnG6fQLcadzuCBJbpIp-zsUL6FkQgUyY2MXwVA0etYvflPe_rDBiuOMV-BfTSGDKt7uU3E2bLUhsD1rrXwGT9BTPcOOH_Vh9jHDSn2inqk8udwQIRcxuc",
      response.authorization
    )
    assert response.test?
    assert_equal "Do Not Honour", response.message
    assert_equal "1", response.params["invoicereference"]
  end

  def test_store_calls_sub_methods
    options = {
      :order_id => 1,
      :billing_address => {
        :name => "Jim Awesome Smith",
      }
    }
    @gateway.expects(:purchase).with(0, @credit_card, options.merge(:request_method => "CreateTokenCustomer"))

    @gateway.store(@credit_card, options)
  end

  def test_verification_results
    response = stub_comms do
      @gateway.status("thetransauth")
    end.respond_with(successful_status_response(:verification_status => "Valid"))

    assert_success response
    assert_equal "M", response.cvv_result["code"]
    assert_equal "M", response.avs_result["code"]

    response = stub_comms do
      @gateway.status("thetransauth")
    end.respond_with(successful_status_response(:verification_status => "Invalid"))

    assert_success response
    assert_equal "N", response.cvv_result["code"]
    assert_equal "N", response.avs_result["code"]

    response = stub_comms do
      @gateway.status("thetransauth")
    end.respond_with(successful_status_response(:verification_status => "Unchecked"))

    assert_success response
    assert_equal "P", response.cvv_result["code"]
    assert_equal "I", response.avs_result["code"]
  end

  private

  def successful_setup_purchase_response
    %(
      <CreateAccessCodeResponse>
        <AccessCode>60CF3xWrFUQeDCEsJcA8zNHaspAT3CKpe-0DiqWjTYA3RZw1xhw2LU-BFCNYbr7eJt8KFaxCxmzYh9WDAYX8yIuYexTq0tC8i2kOt0dm0EV-mjxYEQ2YeHP2dazkSc7j58OiT</AccessCode>
        <Customer>
          <TokenCustomerID p3:nil=\"true\" xmlns:p3=\"http://www.w3.org/2001/XMLSchema-instance\" />
          <Reference />
          <Title />
          <FirstName />
          <LastName />
          <CompanyName />
          <JobDescription />
          <Street1 />
          <Street2 />
          <City />
          <State />
          <PostalCode />
          <Country />
          <Email />
          <Phone />
          <Mobile />
          <Comments />
          <Fax />
          <Url />
          <CardNumber />
          <CardStartMonth />
          <CardStartYear />
          <CardIssueNumber />
          <CardName />
          <CardExpiryMonth />
          <CardExpiryYear />
          <IsActive>false</IsActive>
        </Customer>
        <Payment>
          <TotalAmount>100</TotalAmount>
          <InvoiceDescription>Store Purchase</InvoiceDescription>
          <InvoiceReference>1</InvoiceReference>
          <CurrencyCode>AUD</CurrencyCode>
        </Payment>
        <FormActionURL>https://secure-au.sandbox.ewaypayments.com/Process</FormActionURL>
      </CreateAccessCodeResponse>
    )
  end

  def failed_setup_purchase_response
    %(
      <CreateAccessCodeResponse>
        <Errors>V6047</Errors>
        <Customer>
          <TokenCustomerID p3:nil="true" xmlns:p3="http://www.w3.org/2001/XMLSchema-instance" />
          <IsActive>false</IsActive>
        </Customer>
        <Payment>
          <TotalAmount>100</TotalAmount>
          <CurrencyCode>AUD</CurrencyCode>
        </Payment>
      </CreateAccessCodeResponse>
    )
  end

  def successful_status_response(options={})
    verification_status = (options[:verification_status] || "Unchecked")
    %(
      <GetAccessCodeResultResponse>
        <AccessCode>60CF3sfH7-yvAsUAHrdIiGppPrQW7v7DMAXxKkaKwyrIUoqvUvK44XbK9G9HNbngIz_iwQpfmPT_duMgh2G0pXCX8i4z1RAmMHpUQwa6VrghV3Bx9rh_tojjym7LC_fE-eR97</AccessCode>
        <AuthorisationCode>957199</AuthorisationCode>
        <ResponseCode>00</ResponseCode>
        <ResponseMessage>A2000</ResponseMessage>
        <InvoiceNumber />
        <InvoiceReference>orderid1</InvoiceReference>
        <TotalAmount>100</TotalAmount>
        <TransactionID>9942726</TransactionID>
        <TransactionStatus>true</TransactionStatus>
        <TokenCustomerID p2:nil=\"true\" xmlns:p2=\"http://www.w3.org/2001/XMLSchema-instance\" />
        <BeagleScore>0</BeagleScore>
        <Options />
        <Verification>
          <CVN>#{verification_status}</CVN>
          <Address>#{verification_status}</Address>
          <Email>#{verification_status}</Email>
          <Mobile>#{verification_status}</Mobile>
          <Phone>#{verification_status}</Phone>
        </Verification>
      </GetAccessCodeResultResponse>
    )
  end

  def failed_status_response
    %(
      <GetAccessCodeResultResponse>
        <AccessCode>A1001WfAHR_QP8daLnG6fQLcadzuCBJbpIp-zsUL6FkQgUyY2MXwVA0etYvflPe_rDBiuOMV-BfTSGDKt7uU3E2bLUhsD1rrXwGT9BTPcOOH_Vh9jHDSn2inqk8udwQIRcxuc</AccessCode>
        <AuthorisationCode />
        <ResponseCode>05</ResponseCode>
        <ResponseMessage>D4405</ResponseMessage>
        <InvoiceNumber />
        <InvoiceReference>1</InvoiceReference>
        <TotalAmount>105</TotalAmount>
        <TransactionID>9942743</TransactionID>
        <TransactionStatus>false</TransactionStatus>
        <TokenCustomerID p2:nil=\"true\" xmlns:p2=\"http://www.w3.org/2001/XMLSchema-instance\" />
        <BeagleScore>0</BeagleScore>
        <Options />
        <Verification>
          <CVN>Unchecked</CVN>
          <Address>Unchecked</Address>
          <Email>Unchecked</Email>
          <Mobile>Unchecked</Mobile>
          <Phone>Unchecked</Phone>
        </Verification>
      </GetAccessCodeResultResponse>
    )
  end

  class MockResponse
    attr_reader :code, :body
    def initialize(code, body, headers={})
      @code, @body, @headers = code, body, headers
    end

    def [](header)
      @headers[header]
    end
  end

  def successful_run_purchase_response
    MockResponse.new(
      302,
      %(
        <html><head><title>Object moved</title></head><body>
        <h2>Object moved to <a href="http://example.com/?AccessCode=60CF3xWrFUQeDCEsJcA8zNHaspAT3CKpe-0DiqWjTYA3RZw1xhw2LU-BFCNYbr7eJt8KFaxCxmzYh9WDAYX8yIuYexTq0tC8i2kOt0dm0EV-mjxYEQ2YeHP2dazkSc7j58OiT">here</a>.</h2>
        </body></html>
      ),
      "Location" => "http://example.com/?AccessCode=60CF3xWrFUQeDCEsJcA8zNHaspAT3CKpe-0DiqWjTYA3RZw1xhw2LU-BFCNYbr7eJt8KFaxCxmzYh9WDAYX8yIuYexTq0tC8i2kOt0dm0EV-mjxYEQ2YeHP2dazkSc7j58OiT"
    )
  end

  def failed_run_purchase_response
    MockResponse.new(
      200,
      %(
        {"Message":"Not Found","Errors":null}
      )
    )
  end
end
