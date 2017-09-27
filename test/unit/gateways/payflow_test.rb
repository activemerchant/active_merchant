require 'test_helper'

class PayflowTest < Test::Unit::TestCase
  include CommStub

  def setup
    Base.mode = :test

    @gateway = PayflowGateway.new(
      :login => 'LOGIN',
      :password => 'PASSWORD'
    )

    @amount = 100
    @credit_card = credit_card('4242424242424242')
    @options = { :billing_address => address.merge(:first_name => "Longbob", :last_name => "Longsen") }
    @check = check( :name => 'Jim Smith' )
  end

  def test_successful_authorization
    @gateway.stubs(:ssl_post).returns(successful_authorization_response)

    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_equal "Approved", response.message
    assert_success response
    assert response.test?
    assert_equal "VUJN1A6E11D9", response.authorization
    refute response.fraud_review?
  end

  def test_failed_authorization
    @gateway.stubs(:ssl_post).returns(failed_authorization_response)

    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_equal "Declined", response.message
    assert_failure response
    assert response.test?
  end

  def test_authorization_with_three_d_secure_option
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, @options.merge(three_d_secure_option))
    end.check_request do |endpoint, data, headers|
      assert_three_d_secure REXML::Document.new(data), authorize_buyer_auth_result_path
    end.respond_with(successful_authorization_response)
    assert_equal "Approved", response.message
    assert_success response
    assert response.test?
    assert_equal "VUJN1A6E11D9", response.authorization
    refute response.fraud_review?
  end

  def test_successful_purchase_with_fraud_review
    @gateway.stubs(:ssl_post).returns(successful_purchase_with_fraud_review_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal "126", response.params["result"]
    assert response.fraud_review?
  end

  def test_successful_purchase_with_three_d_secure_option
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(three_d_secure_option))
    end.check_request do |endpoint, data, headers|
      assert_three_d_secure REXML::Document.new(data), purchase_buyer_auth_result_path
    end.respond_with(successful_purchase_with_fraud_review_response)
    assert_success response
    assert_equal "126", response.params["result"]
    assert response.fraud_review?
  end

  def test_credit
    @gateway.expects(:ssl_post).with(anything, regexp_matches(/<CardNum>#{@credit_card.number}<\//), anything).returns("")
    @gateway.expects(:parse).returns({})
    @gateway.credit(@amount, @credit_card, @options)
  end

  def test_deprecated_credit
    @gateway.expects(:ssl_post).with(anything, regexp_matches(/<PNRef>transaction_id<\//), anything).returns("")
    @gateway.expects(:parse).returns({})
    assert_deprecation_warning(Gateway::CREDIT_DEPRECATION_MESSAGE) do
      @gateway.credit(@amount, "transaction_id", @options)
    end
  end

  def test_refund
    @gateway.expects(:ssl_post).with(anything, regexp_matches(/<PNRef>transaction_id<\//), anything).returns("")
    @gateway.expects(:parse).returns({})
    @gateway.refund(@amount, "transaction_id", @options)
  end

  def test_avs_result
    @gateway.expects(:ssl_post).returns(successful_authorization_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'Y', response.avs_result['code']
    assert_equal 'Y', response.avs_result['street_match']
    assert_equal 'Y', response.avs_result['postal_match']
  end

  def test_partial_avs_match
    @gateway.expects(:ssl_post).returns(successful_duplicate_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'A', response.avs_result['code']
    assert_equal 'Y', response.avs_result['street_match']
    assert_equal 'N', response.avs_result['postal_match']
  end

  def test_cvv_result
    @gateway.expects(:ssl_post).returns(successful_authorization_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'M', response.cvv_result['code']
  end

  def test_ach_purchase
    @gateway.expects(:ssl_post).with(anything, regexp_matches(/<AcctNum>#{@check.account_number}<\//), anything).returns("")
    @gateway.expects(:parse).returns({})
    @gateway.purchase(@amount, @check)
  end

  def test_ach_credit
    @gateway.expects(:ssl_post).with(anything, regexp_matches(/<AcctNum>#{@check.account_number}<\//), anything).returns("")
    @gateway.expects(:parse).returns({})
    @gateway.credit(@amount, @check)
  end

  def test_using_test_mode
    assert @gateway.test?
  end

  def test_overriding_test_mode
    Base.mode = :production

    gateway = PayflowGateway.new(
      :login => 'LOGIN',
      :password => 'PASSWORD',
      :test => true
    )

    assert gateway.test?
  end

  def test_using_production_mode
    Base.mode = :production

    gateway = PayflowGateway.new(
      :login => 'LOGIN',
      :password => 'PASSWORD'
    )

    refute gateway.test?
  end

  def test_partner_class_accessor
    assert_equal 'PayPal', PayflowGateway.partner
    gateway = PayflowGateway.new(:login => 'test', :password => 'test')
    assert_equal 'PayPal', gateway.options[:partner]
  end

  def test_partner_class_accessor_used_when_passed_in_partner_is_blank
    assert_equal 'PayPal', PayflowGateway.partner
    gateway = PayflowGateway.new(:login => 'test', :password => 'test', :partner => '')
    assert_equal 'PayPal', gateway.options[:partner]
  end

  def test_passed_in_partner_overrides_class_accessor
    assert_equal 'PayPal', PayflowGateway.partner
    gateway = PayflowGateway.new(:login => 'test', :password => 'test', :partner => 'PayPalUk')
    assert_equal 'PayPalUk', gateway.options[:partner]
  end

  def test_express_instance
    gateway = PayflowGateway.new(
      :login => 'test',
      :password => 'password'
    )
    express = gateway.express
    assert_instance_of PayflowExpressGateway, express
    assert_equal 'PayPal', express.options[:partner]
    assert_equal 'test', express.options[:login]
    assert_equal 'password', express.options[:password]
  end

  def test_default_currency
    assert_equal 'USD', PayflowGateway.default_currency
  end

  def test_supported_countries
    assert_equal ['US', 'CA', 'NZ', 'AU'], PayflowGateway.supported_countries
  end

  def test_supported_card_types
    assert_equal [:visa, :master, :american_express, :jcb, :discover, :diners_club], PayflowGateway.supported_cardtypes
  end

  def test_successful_verify
    response = stub_comms(@gateway) do
      @gateway.verify(@credit_card, @options)
    end.respond_with(successful_authorization_response)
    assert_success response
  end

  def test_unsuccessful_verify
    response = stub_comms(@gateway) do
      @gateway.verify(@credit_card, @options)
    end.respond_with(failed_authorization_response)
    assert_failure response
    assert_equal "Declined", response.message
  end

  def test_initial_recurring_transaction_missing_parameters
    assert_raises ArgumentError do
      assert_deprecation_warning(Gateway::RECURRING_DEPRECATION_MESSAGE) do
        @gateway.recurring(@amount, @credit_card,
          :periodicity => :monthly,
          :initial_transaction => { }
        )
      end
    end
  end

  def test_initial_purchase_missing_amount
    assert_raises ArgumentError do
      assert_deprecation_warning(Gateway::RECURRING_DEPRECATION_MESSAGE) do
        @gateway.recurring(@amount, @credit_card,
          :periodicity => :monthly,
          :initial_transaction => { :amount => :purchase }
        )
      end
    end
  end

  def test_recurring_add_action_missing_parameters
    assert_raises ArgumentError do
      assert_deprecation_warning(Gateway::RECURRING_DEPRECATION_MESSAGE) do
        @gateway.recurring(@amount, @credit_card)
      end
    end
  end

  def test_recurring_modify_action_missing_parameters
    assert_raises ArgumentError do
      assert_deprecation_warning(Gateway::RECURRING_DEPRECATION_MESSAGE) do
        @gateway.recurring(@amount, nil)
      end
    end
  end

  def test_successful_recurring_action
    @gateway.stubs(:ssl_post).returns(successful_recurring_response)

    response = assert_deprecation_warning(Gateway::RECURRING_DEPRECATION_MESSAGE) do
      @gateway.recurring(@amount, @credit_card, :periodicity => :monthly)
    end

    assert_instance_of PayflowResponse, response
    assert_success response
    assert_equal 'RT0000000009', response.profile_id
    assert response.test?
    assert_equal "R7960E739F80", response.authorization
  end

  def test_successful_recurring_modify_action
    @gateway.stubs(:ssl_post).returns(successful_recurring_response)

    response = assert_deprecation_warning(Gateway::RECURRING_DEPRECATION_MESSAGE) do
      @gateway.recurring(@amount, nil, :profile_id => "RT0000000009", :periodicity => :monthly)
    end

    assert_instance_of PayflowResponse, response
    assert_success response
    assert_equal 'RT0000000009', response.profile_id
    assert response.test?
    assert_equal "R7960E739F80", response.authorization
  end

  def test_successful_recurring_modify_action_with_retry_num_days
    @gateway.stubs(:ssl_post).returns(successful_recurring_response)

    response = assert_deprecation_warning(Gateway::RECURRING_DEPRECATION_MESSAGE) do
      @gateway.recurring(@amount, nil, :profile_id => "RT0000000009", :retry_num_days => 3, :periodicity => :monthly)
    end

    assert_instance_of PayflowResponse, response
    assert_success response
    assert_equal 'RT0000000009', response.profile_id
    assert response.test?
    assert_equal "R7960E739F80", response.authorization
  end

  def test_falied_recurring_modify_action_with_starting_at_in_the_past
    @gateway.stubs(:ssl_post).returns(start_date_error_recurring_response)

    response = assert_deprecation_warning(Gateway::RECURRING_DEPRECATION_MESSAGE) do
      @gateway.recurring(@amount, nil, :profile_id => "RT0000000009", :starting_at => Date.yesterday, :periodicity => :monthly)
    end

    assert_instance_of PayflowResponse, response
    assert_success response
    assert_equal 'RT0000000009', response.profile_id
    assert_equal 'Field format error: START or NEXTPAYMENTDATE older than last payment date', response.message
    assert response.test?
    assert_equal "R7960E739F80", response.authorization
  end

  def test_falied_recurring_modify_action_with_starting_at_missing_and_changed_periodicity
    @gateway.stubs(:ssl_post).returns(start_date_missing_recurring_response)

    response = assert_deprecation_warning(Gateway::RECURRING_DEPRECATION_MESSAGE) do
      @gateway.recurring(@amount, nil, :profile_id => "RT0000000009", :periodicity => :yearly)
    end

    assert_instance_of PayflowResponse, response
    assert_success response
    assert_equal 'RT0000000009', response.profile_id
    assert_equal 'Field format error: START field missing', response.message
    assert response.test?
    assert_equal "R7960E739F80", response.authorization
  end

  def test_recurring_profile_payment_history_inquiry
    @gateway.stubs(:ssl_post).returns(successful_payment_history_recurring_response)

    response = assert_deprecation_warning(Gateway::RECURRING_DEPRECATION_MESSAGE) do
      @gateway.recurring_inquiry('RT0000000009', :history => true)
    end
    assert_equal 1, response.payment_history.size
    assert_equal '1', response.payment_history.first['payment_num']
    assert_equal '7.25', response.payment_history.first['amt']
  end

  def test_recurring_profile_payment_history_inquiry_contains_the_proper_xml
    request = @gateway.send( :build_recurring_request, :inquiry, nil, :profile_id => 'RT0000000009', :history => true)
    assert_match %r(<PaymentHistory>Y</PaymentHistory), request
  end

  def test_format_issue_number
    xml = Builder::XmlMarkup.new
    credit_card = credit_card("5641820000000005",
      :brand         => "switch",
      :issue_number  => 1
    )

    @gateway.send(:add_credit_card, xml, credit_card)
    doc = REXML::Document.new(xml.target!)
    node = REXML::XPath.first(doc, '/Card/ExtData')
    assert_equal '01', node.attributes['Value']
  end

  def test_add_credit_card_with_three_d_secure
    xml = Builder::XmlMarkup.new
    credit_card = credit_card("5641820000000005",
                              :brand => "switch",
                              :issue_number => 1
    )

    @gateway.send(:add_credit_card, xml, credit_card, @options.merge(three_d_secure_option))
    assert_three_d_secure REXML::Document.new(xml.target!), '/Card/BuyerAuthResult'
  end

  def test_duplicate_response_flag
    @gateway.expects(:ssl_post).returns(successful_duplicate_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert response.params['duplicate']
  end

  def test_ensure_gateway_uses_safe_retry
    assert @gateway.retry_safe
  end

  def test_timeout_is_same_in_header_and_xml
    timeout = PayflowGateway.timeout.to_s

    headers = @gateway.send(:build_headers, 1)
    assert_equal timeout, headers['X-VPS-Client-Timeout']

    xml = @gateway.send(:build_request, 'dummy body')
    assert_match %r{Timeout="#{timeout}"}, xml
  end

  def test_name_field_are_included_instead_of_first_and_last
    @gateway.expects(:ssl_post).returns(successful_authorization_response).with do |url, data|
      data !~ /FirstName/ && data !~ /LastName/ && data =~ /<Name>/
    end
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
  end

  def test_passed_in_verbosity
    assert_nil PayflowGateway.new(:login => 'test', :password => 'test').options[:verbosity]
    gateway = PayflowGateway.new(:login => 'test', :password => 'test', :verbosity => 'HIGH')
    assert_equal 'HIGH', gateway.options[:verbosity]
    @gateway.expects(:ssl_post).returns(verbose_transaction_response)
    response = @gateway.purchase(100, @credit_card, @options)
    assert_success response
    assert_equal '2014-06-25 09:33:41', response.params['transaction_time']
  end

  def test_paypal_nvp_option_sends_header
    headers = @gateway.send(:build_headers, 1)
    assert_not_include headers, 'PAYPAL-NVP'

    old_use_paypal_nvp = PayflowGateway.use_paypal_nvp
    PayflowGateway.use_paypal_nvp = true
    headers = @gateway.send(:build_headers, 1)
    assert_equal 'Y', headers['PAYPAL-NVP']
    PayflowGateway.use_paypal_nvp = old_use_paypal_nvp
  end

  private
  def successful_recurring_response
    <<-XML
<ResponseData>
  <Result>0</Result>
  <Message>Approved</Message>
  <Partner>paypal</Partner>
  <RPRef>R7960E739F80</RPRef>
  <Vendor>ActiveMerchant</Vendor>
  <ProfileId>RT0000000009</ProfileId>
</ResponseData>
  XML
  end

  def start_date_error_recurring_response
      <<-XML
  <ResponseData>
    <Result>0</Result>
    <Message>Field format error: START or NEXTPAYMENTDATE older than last payment date</Message>
    <Partner>paypal</Partner>
    <RPRef>R7960E739F80</RPRef>
    <Vendor>ActiveMerchant</Vendor>
    <ProfileId>RT0000000009</ProfileId>
  </ResponseData>
    XML
  end

  def start_date_missing_recurring_response
      <<-XML
  <ResponseData>
    <Result>0</Result>
    <Message>Field format error: START field missing</Message>
    <Partner>paypal</Partner>
    <RPRef>R7960E739F80</RPRef>
    <Vendor>ActiveMerchant</Vendor>
    <ProfileId>RT0000000009</ProfileId>
  </ResponseData>
    XML
  end

  def successful_payment_history_recurring_response
    <<-XML
<ResponseData>
  <Result>0</Result>
  <Partner>paypal</Partner>
  <RPRef>R7960E739F80</RPRef>
  <Vendor>ActiveMerchant</Vendor>
  <ProfileId>RT0000000009</ProfileId>
  <RPPaymentResult>
    <PaymentNum>1</PaymentNum>
    <PNRef>V18A0D3048AF</PNRef>
    <TransTime>12-Jan-08 04:30 AM</TransTime>
    <Result>0</Result>
    <Tender>C</Tender>
    <Amt Currency="7.25"></Amt>
    <TransState>6</TransState>
  </RPPaymentResult>
</ResponseData>
  XML
  end

  def successful_authorization_response
    <<-XML
<ResponseData>
    <Result>0</Result>
    <Message>Approved</Message>
    <Partner>verisign</Partner>
    <HostCode>000</HostCode>
    <ResponseText>AP</ResponseText>
    <PnRef>VUJN1A6E11D9</PnRef>
    <IavsResult>N</IavsResult>
    <ZipMatch>Match</ZipMatch>
    <AuthCode>094016</AuthCode>
    <Vendor>ActiveMerchant</Vendor>
    <AvsResult>Y</AvsResult>
    <StreetMatch>Match</StreetMatch>
    <CvResult>Match</CvResult>
</ResponseData>
    XML
  end

  def failed_authorization_response
    <<-XML
<ResponseData>
    <Result>12</Result>
    <Message>Declined</Message>
    <Partner>verisign</Partner>
    <HostCode>000</HostCode>
    <ResponseText>AP</ResponseText>
    <PnRef>VUJN1A6E11D9</PnRef>
    <IavsResult>N</IavsResult>
    <ZipMatch>Match</ZipMatch>
    <AuthCode>094016</AuthCode>
    <Vendor>ActiveMerchant</Vendor>
    <AvsResult>Y</AvsResult>
    <StreetMatch>Match</StreetMatch>
    <CvResult>Match</CvResult>
</ResponseData>
    XML
  end

  def successful_purchase_with_fraud_review_response
    <<-XML
      <XMLPayResponse  xmlns="http://www.paypal.com/XMLPay">
        <ResponseData>
          <Vendor>spreedly</Vendor>
          <Partner>paypal</Partner>
          <TransactionResults>
            <TransactionResult>
              <Result>126</Result>
              <ProcessorResult>
                <HostCode>A</HostCode>
              </ProcessorResult>
              <FraudPreprocessResult>
                <Message>Review HighRiskBinCheck</Message>
                <XMLData>
                  <triggeredRules>
                    <rule num="1">
                      <ruleId>13</ruleId>
                      <ruleID>13</ruleID>
                      <ruleAlias>HighRiskBinCheck</ruleAlias>
                      <ruleDescription>BIN Risk List Match</ruleDescription>
                      <action>R</action>
                      <triggeredMessage>The card number is in a high risk bin list</triggeredMessage>
                    </rule>
                  </triggeredRules>
                </XMLData>
              </FraudPreprocessResult>
              <FraudPostprocessResult>
                <Message>Review</Message>
              </FraudPostprocessResult>
              <Message>Under review by Fraud Service</Message>
              <PNRef>A71A7B022DC0</PNRef>
              <AuthCode>907PNI</AuthCode>
            </TransactionResult>
          </TransactionResults>
        </ResponseData>
      </XMLPayResponse>
    XML
  end

  def successful_duplicate_response
    <<-XML
<?xml version="1.0"?>
<XMLPayResponse xmlns="http://www.verisign.com/XMLPay">
	<ResponseData>
		<Vendor>ActiveMerchant</Vendor>
		<Partner>paypal</Partner>
		<TransactionResults>
			<TransactionResult Duplicate="true">
				<Result>0</Result>
				<ProcessorResult>
					<AVSResult>A</AVSResult>
					<CVResult>M</CVResult>
					<HostCode>A</HostCode>
				</ProcessorResult>
				<IAVSResult>N</IAVSResult>
				<AVSResult>
					<StreetMatch>Match</StreetMatch>
					<ZipMatch>No Match</ZipMatch>
				</AVSResult>
				<CVResult>Match</CVResult>
				<Message>Approved</Message>
				<PNRef>V18A0CBB04CF</PNRef>
				<AuthCode>692PNI</AuthCode>
				<ExtData Name="DATE_TO_SETTLE" Value="2007-11-28 10:53:50"/>
			</TransactionResult>
		</TransactionResults>
	</ResponseData>
</XMLPayResponse>
    XML
  end

  def verbose_transaction_response
    <<-XML
<?xml version="1.0" encoding="UTF-8"?>
<XMLPayResponse  xmlns="http://www.paypal.com/XMLPay">
  <ResponseData>
    <Vendor>ActiveMerchant</Vendor>
    <Partner>paypal</Partner>
    <TransactionResults>
      <TransactionResult>
        <Result>0</Result>
        <ProcessorResult>
          <AVSResult>U</AVSResult>
          <CVResult>M</CVResult>
          <HostCode>A</HostCode>
        </ProcessorResult>
        <FraudPreprocessResult>
          <Message>No Rules Triggered</Message>
        </FraudPreprocessResult>
        <FraudPostprocessResult>
          <Message>No Rules Triggered</Message>
        </FraudPostprocessResult>
        <IAVSResult>X</IAVSResult>
        <AVSResult>
          <StreetMatch>Service Not Available</StreetMatch>
          <ZipMatch>Service Not Available</ZipMatch>
        </AVSResult>
        <CVResult>Match</CVResult>
        <Message>Approved</Message>
        <PNRef>A70A6C93C4C8</PNRef>
        <AuthCode>242PNI</AuthCode>
        <Amount>1.00</Amount>
        <VisaCardLevel>12</VisaCardLevel>
        <TransactionTime>2014-06-25 09:33:41</TransactionTime>
        <Account>4242</Account>
        <ExpirationDate>0714</ExpirationDate>
        <CardType>0</CardType>
        <PayPalResult>
          <FeeAmount>0</FeeAmount>
          <Name>Longbob</Name>
          <Lastname>Longsen</Lastname>
        </PayPalResult>
      </TransactionResult>
    </TransactionResults>
  </ResponseData>
</XMLPayResponse>
    XML
  end

  def assert_three_d_secure(xml_doc, buyer_auth_result_path)
    assert_equal 'Y', REXML::XPath.first(xml_doc, "#{buyer_auth_result_path}/Status").text
    assert_equal 'QvDbSAxSiaQs241899E0', REXML::XPath.first(xml_doc, "#{buyer_auth_result_path}/AuthenticationId").text
    assert_equal 'pareq block', REXML::XPath.first(xml_doc, "#{buyer_auth_result_path}/PAReq").text
    assert_equal 'https://bankacs.bank.com/ascurl', REXML::XPath.first(xml_doc, "#{buyer_auth_result_path}/ACSUrl").text
    assert_equal '02', REXML::XPath.first(xml_doc, "#{buyer_auth_result_path}/ECI").text
    assert_equal 'jGvQIvG/5UhjAREALGYa6Vu/hto=', REXML::XPath.first(xml_doc, "#{buyer_auth_result_path}/CAVV").text
    assert_equal 'UXZEYlNBeFNpYVFzMjQxODk5RTA=', REXML::XPath.first(xml_doc, "#{buyer_auth_result_path}/XID").text
  end

  def authorize_buyer_auth_result_path
    '/XMLPayRequest/RequestData/Transactions/Transaction/Authorization/PayData/Tender/Card/BuyerAuthResult'
  end

  def purchase_buyer_auth_result_path
    '/XMLPayRequest/RequestData/Transactions/Transaction/Sale/PayData/Tender/Card/BuyerAuthResult'
  end

  def three_d_secure_option
    {
        :three_d_secure => {
            :status => 'Y',
            :authentication_id => 'QvDbSAxSiaQs241899E0',
            :pareq => 'pareq block',
            :acs_url => 'https://bankacs.bank.com/ascurl',
            :eci => '02',
            :cavv => 'jGvQIvG/5UhjAREALGYa6Vu/hto=',
            :xid => 'UXZEYlNBeFNpYVFzMjQxODk5RTA='
        }
    }
  end
end
