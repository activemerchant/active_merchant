require 'test_helper'

class SagePayTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = SagePayGateway.new(login: 'X')

    @credit_card = credit_card('4242424242424242', :brand => 'visa')
    @electron_credit_card = credit_card('4245190000000000', :brand => 'visa')
    @options = {
      :billing_address => {
        :name => 'Tekin Suleyman',
        :address1 => 'Flat 10 Lapwing Court',
        :address2 => 'West Didsbury',
        :city => "Manchester",
        :county => 'Greater Manchester',
        :country => 'GB',
        :zip => 'M20 2PS'
      },
      :order_id => '1',
      :description => 'Store purchase',
      :ip => '86.150.65.37',
      :email => 'tekin@tekin.co.uk',
      :phone => '0161 123 4567'
    }
    @amount = 100
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal "1;B8AE1CF6-9DEF-C876-1BB4-9B382E6CE520;4193753;OHMETD7DFK;purchase", response.authorization
    assert_success response
  end

  def test_electron_card_type_is_set_correctly
    @gateway.expects(:ssl_post).with(anything, regexp_matches(/CardType=UKE/)).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @electron_credit_card, @options)
    assert_success response
  end

  def test_unsuccessful_purchase
    @gateway.expects(:ssl_post).returns(unsuccessful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end

  def test_purchase_url
    assert_equal 'https://test.sagepay.com/gateway/service/vspdirect-register.vsp', @gateway.send(:url_for, :purchase)
  end

  def test_capture_url
    assert_equal 'https://test.sagepay.com/gateway/service/release.vsp', @gateway.send(:url_for, :capture)
  end

  def test_avs_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'Y', response.avs_result['postal_match']
    assert_equal 'N', response.avs_result['street_match']
  end

   def test_cvv_result
     @gateway.expects(:ssl_post).returns(successful_purchase_response)

     response = @gateway.purchase(@amount, @credit_card, @options)
     assert_equal 'N', response.cvv_result['code']
   end

  def test_dont_send_fractional_amount_for_chinese_yen
    @amount = 100_00  # 100 YEN
    @options[:currency] = 'JPY'

    @gateway.expects(:add_pair).with({}, :Amount, '100', :required => true)
    @gateway.expects(:add_pair).with({}, :Currency, 'JPY', :required => true)

    @gateway.send(:add_amount, {}, @amount, @options)
  end

  def test_send_fractional_amount_for_british_pounds
    @gateway.expects(:add_pair).with({}, :Amount, '1.00', :required => true)
    @gateway.expects(:add_pair).with({}, :Currency, 'GBP', :required => true)

    @gateway.send(:add_amount, {}, @amount, @options)
  end

  def test_paypal_callback_url_is_submitted
    stub_comms(@gateway, :ssl_request) do
      purchase_with_options(paypal_callback_url: 'callback.com')
    end.check_request do |method, endpoint, data, headers|
      assert_match(/PayPalCallbackURL=callback\.com/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_basket_is_submitted
    stub_comms(@gateway, :ssl_request) do
      purchase_with_options(basket: 'A1.2 Basket section')
    end.check_request do |method, endpoint, data, headers|
      assert_match(/Basket=A1\.2\+Basket\+section/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_gift_aid_payment_is_submitted
    stub_comms(@gateway, :ssl_request) do
      purchase_with_options(gift_aid_payment: 1)
    end.check_request do |method, endpoint, data, headers|
      assert_match(/GiftAidPayment=1/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_apply_avscv2_is_submitted
    stub_comms(@gateway, :ssl_request) do
      purchase_with_options(apply_avscv2: 1)
    end.check_request do |method, endpoint, data, headers|
      assert_match(/ApplyAVSCV2=1/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_disable_3d_security_flag_is_submitted
    stub_comms(@gateway, :ssl_request) do
      purchase_with_options(apply_3d_secure: 1)
    end.check_request do |method, endpoint, data, headers|
      assert_match(/Apply3DSecure=1/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_account_type_is_submitted
    stub_comms(@gateway, :ssl_request) do
      purchase_with_options(account_type: 'M')
    end.check_request do |method, endpoint, data, headers|
      assert_match(/AccountType=M/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_billing_agreement_is_submitted
    stub_comms(@gateway, :ssl_request) do
      purchase_with_options(billing_agreement: 1)
    end.check_request do |method, endpoint, data, headers|
      assert_match(/BillingAgreement=1/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_store_token_is_submitted
    stub_comms(@gateway, :ssl_request) do
      purchase_with_options(store: true)
    end.check_request do |method, endpoint, data, headers|
      assert_match(/CreateToken=1/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_basket_xml_is_submitted
    stub_comms(@gateway, :ssl_request) do
      purchase_with_options(basket_xml: 'A1.3 BasketXML section')
    end.check_request do |method, endpoint, data, headers|
      assert_match(/BasketXML=A1\.3\+BasketXML\+section/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_customer_xml_is_submitted
    stub_comms(@gateway, :ssl_request) do
      purchase_with_options(customer_xml: 'A1.4 CustomerXML section')
    end.check_request do |method, endpoint, data, headers|
      assert_match(/CustomerXML=A1\.4\+CustomerXML\+section/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_surcharge_xml_is_submitted
    stub_comms(@gateway, :ssl_request) do
      purchase_with_options(surcharge_xml: 'A1.1 SurchargeXML section')
    end.check_request do |method, endpoint, data, headers|
      assert_match(/SurchargeXML=A1\.1\+SurchargeXML\+section/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_vendor_data_is_submitted
    stub_comms(@gateway, :ssl_request) do
      purchase_with_options(vendor_data: 'any data')
    end.check_request do |method, endpoint, data, headers|
      assert_match(/VendorData=any\+data/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_language_is_submitted
    stub_comms(@gateway, :ssl_request) do
      purchase_with_options(language: 'FR')
    end.check_request do |method, endpoint, data, headers|
      assert_match(/Language=FR/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_website_is_submitted
    stub_comms(@gateway, :ssl_request) do
      purchase_with_options(website: 'transaction-origin.com')
    end.check_request do |method, endpoint, data, headers|
      assert_match(/Website=transaction-origin\.com/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_FIxxxx_optional_fields_are_submitted
    stub_comms(@gateway, :ssl_request) do
      purchase_with_options(recipient_account_number: '1234567890',
        recipient_surname: 'Withnail', recipient_postcode: 'AB11AB',
        recipient_dob: '19701223')
    end.check_request do |method, endpoint, data, headers|
      assert_match(/FIRecipientAcctNumber=1234567890/, data)
      assert_match(/FIRecipientSurname=Withnail/, data)
      assert_match(/FIRecipientPostcode=AB11AB/, data)
      assert_match(/FIRecipientDoB=19701223/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_description_is_truncated
    huge_description = "SagePay transactions fail if the déscription is more than 100 characters. Therefore, we truncate it to 100 characters." + " Lots more text " * 1000
    stub_comms(@gateway, :ssl_request) do
      purchase_with_options(description: huge_description)
    end.check_request do |method, endpoint, data, headers|
      assert_match(/&Description=SagePay\+transactions\+fail\+if\+the\+d%C3%A9scription\+is\+more\+than\+100\+characters.\+Therefore%2C\+we\+trunc&/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_protocol_version_is_honoured
    gateway = SagePayGateway.new(protocol_version: '2.23', login: "X")

    stub_comms(gateway, :ssl_request) do
      gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |method, endpoint, data, headers|
      assert_match(/VPSProtocol=2.23/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_referrer_id_is_added_to_post_data_parameters
    ActiveMerchant::Billing::SagePayGateway.application_id = '00000000-0000-0000-0000-000000000001'
    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |method, endpoint, data, headers|
      assert data.include?("ReferrerID=00000000-0000-0000-0000-000000000001")
    end.respond_with(successful_purchase_response)
  ensure
    ActiveMerchant::Billing::SagePayGateway.application_id = nil
  end

  def test_successful_store
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.store(@credit_card)
    end.check_request do |method, endpoint, data, headers|
      assert_match(/TxType=TOKEN/, data)
    end.respond_with(successful_purchase_response)

    assert_equal '1', response.authorization
  end

  def test_successful_verify
    response = stub_comms do
      @gateway.verify(@credit_card, @options)
    end.respond_with(successful_authorize_response, successful_void_response)
    assert_success response
  end

  def test_successful_verify_with_failed_void
    response = stub_comms do
      @gateway.verify(@credit_card, @options)
    end.respond_with(successful_authorize_response, unsuccessful_void_response)
    assert_success response
  end

  def test_unsuccessful_verify
    response = stub_comms do
      @gateway.verify(@credit_card, @options)
    end.respond_with(unsuccessful_authorize_response, unsuccessful_void_response)
    assert_failure response
  end

  def test_transcript_scrubbing
    assert_equal scrubbed_transcript, @gateway.scrub(transcript)
  end

  def test_truncate_accounts_for_url_encoding
    assert_nil @gateway.send(:truncate, nil, 3)
    assert_equal "Wow", @gateway.send(:truncate, "WowAmaze", 3)
    assert_equal "Joikam Lomström", @gateway.send(:truncate, "Joikam Lomström Rate", 20)
  end

  def test_successful_authorization_and_capture_and_refund
    auth = stub_comms do
      @gateway.authorize(@amount, @credit_card, @options)
    end.respond_with(successful_authorize_response)
    assert_success auth

    capture = stub_comms do
      @gateway.capture(@amount, auth.authorization)
    end.respond_with(successful_capture_response)
    assert_success capture

    refund = stub_comms do
      @gateway.refund(@amount, capture.authorization,
        order_id: generate_unique_id,
        description: "Refund txn"
       )
    end.respond_with(successful_refund_response)
    assert_success refund
  end

  def test_repeat_purchase_with_reference_token
    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, "1455548a8d178beecd88fe6a285f50ff;{0D2ACAF0-FA64-6DFF-3869-7ADDDC1E0474};15353766;BS231FNE14;purchase", @options)
    end.check_request do |method, endpoint, data, headers|
      assert_match(/RelatedVPSTxId=%7B0D2ACAF0-FA64-6DFF-3869-7ADDDC1E0474%/, data)
      assert_match(/TxType=REPEAT/, data)
    end.respond_with(successful_purchase_response)
  end

  private

  def purchase_with_options(optional)
    @gateway.purchase(@amount, @credit_card, @options.merge(optional))
  end

  def successful_purchase_response
    <<-RESP
VPSProtocol=2.23
Status=OK
StatusDetail=0000 : The Authorisation was Successful.
VPSTxId=B8AE1CF6-9DEF-C876-1BB4-9B382E6CE520
SecurityKey=OHMETD7DFK
TxAuthNo=4193753
AVSCV2=NO DATA MATCHES
AddressResult=NOTMATCHED
PostCodeResult=MATCHED
CV2Result=NOTMATCHED
3DSecureStatus=NOTCHECKED
Token=1
    RESP
  end

  def unsuccessful_purchase_response
    <<-RESP
VPSProtocol=2.23
Status=NOTAUTHED
StatusDetail=VSP Direct transaction from VSP Simulator.
VPSTxId=7BBA9078-8489-48CD-BF0D-10B0E6B0EF30
SecurityKey=DKDYLDYLXV
AVSCV2=ALL MATCH
AddressResult=MATCHED
PostCodeResult=MATCHED
CV2Result=MATCHED
    RESP
  end

  def successful_authorize_response
    <<-RESP
VPSProtocol=2.23
Status=OK
StatusDetail=0000 : The Authorisation was Successful.
VPSTxId=B8AE1CF6-9DEF-C876-1BB4-9B382E6CE520
SecurityKey=OHMETD7DFK
TxAuthNo=4193753
AVSCV2=NO DATA MATCHES
AddressResult=NOTMATCHED
PostCodeResult=MATCHED
CV2Result=NOTMATCHED
3DSecureStatus=NOTCHECKED
Token=1
    RESP
  end

  def successful_refund_response
    <<-RESP
VPSProtocol=3.00
Status=OK
StatusDetail=0000 : The Authorisation was Successful.
SecurityKey=KUMJBP02HM
TxAuthNo=15282432
VPSTxId={08C870A9-1E53-3852-BA44-CBC91612CBCA}
    RESP
  end

  def successful_capture_response
    <<-RESP
VPSProtocol=3.00
Status=OK
StatusDetail=2004 : The Release was Successful.
    RESP
  end

  def unsuccessful_authorize_response
    <<-RESP
VPSProtocol=2.23
Status=NOTAUTHED
StatusDetail=VSP Direct transaction from VSP Simulator.
VPSTxId=7BBA9078-8489-48CD-BF0D-10B0E6B0EF30
SecurityKey=DKDYLDYLXV
AVSCV2=ALL MATCH
AddressResult=MATCHED
PostCodeResult=MATCHED
CV2Result=MATCHED
    RESP
  end

  def successful_void_response
    <<-RESP
VPSProtocol=2.23
Status=OK
StatusDetail=2006 : The Abort was Successful.
VPSTxId=B8AE1CF6-9DEF-C876-1BB4-9B382E6CE520
SecurityKey=OHMETD7DFK
TxAuthNo=4193753
AVSCV2=NO DATA MATCHES
AddressResult=NOTMATCHED
PostCodeResult=MATCHED
CV2Result=NOTMATCHED
3DSecureStatus=NOTCHECKED
Token=1
    RESP
  end

  def unsuccessful_void_response
    <<-RESP
VPSProtocol=2.23
Status=MALFORMED
StatusDetail=3046 : The VPSTxId field is missing.
VPSTxId=7BBA9078-8489-48CD-BF0D-10B0E6B0EF30
SecurityKey=DKDYLDYLXV
AVSCV2=ALL MATCH
AddressResult=MATCHED
PostCodeResult=MATCHED
CV2Result=MATCHED
    RESP
  end

  def transcript
    <<-TRANSCRIPT
    Amount=1.00&Currency=GBP&VendorTxCode=9094108b21f7b917e68d3e84b49ce9c4&Description=Store+purchase&CardHolder=Tekin+Suleyman&CardNumber=4929000000006&ExpiryDate=0616&CardType=VISA&CV2=123&BillingSurname=Suleyman&BillingFirstnames=Tekin&BillingAddress1=Flat+10+Lapwing+Court&BillingAddress2=West+Didsbury&BillingCity=Manchester&BillingCountry=GB&BillingPostCode=M20+2PS&DeliverySurname=Suleyman&DeliveryFirstnames=Tekin&DeliveryAddress1=120+Grosvenor+St&DeliveryCity=Manchester&DeliveryCountry=GB&DeliveryPostCode=M1+7QW&CustomerEMail=tekin%40tekin.co.uk&ClientIPAddress=86.150.65.37&Vendor=spreedly&TxType=PAYMENT&VPSProtocol=3.00
I, [2015-07-22T17:16:49.292774 #97998]  INFO -- : [ActiveMerchant::Billing::SagePayGateway] --> 200 OK (356 1.8635s)
D, [2015-07-22T17:16:49.292836 #97998] DEBUG -- : VPSProtocol=3.00
Status=OK
StatusDetail=0000 : The Authorisation was Successful.
VPSTxId={D5B43220-E93C-ED13-6643-D22224BD1CDB}
SecurityKey=7OYK4OHM7Y
TxAuthNo=8769237
AVSCV2=DATA NOT CHECKED
AddressResult=NOTPROVIDED
PostCodeResult=NOTPROVIDED
CV2Result=NOTPROVIDED
3DSecureStatus=NOTCHECKED
DeclineCode=00
ExpiryDate=0616
BankAuthCode=999777
  TRANSCRIPT

  end

  def scrubbed_transcript
    <<-TRANSCRIPT
    Amount=1.00&Currency=GBP&VendorTxCode=9094108b21f7b917e68d3e84b49ce9c4&Description=Store+purchase&CardHolder=Tekin+Suleyman&CardNumber=[FILTERED]&ExpiryDate=0616&CardType=VISA&CV2=[FILTERED]&BillingSurname=Suleyman&BillingFirstnames=Tekin&BillingAddress1=Flat+10+Lapwing+Court&BillingAddress2=West+Didsbury&BillingCity=Manchester&BillingCountry=GB&BillingPostCode=M20+2PS&DeliverySurname=Suleyman&DeliveryFirstnames=Tekin&DeliveryAddress1=120+Grosvenor+St&DeliveryCity=Manchester&DeliveryCountry=GB&DeliveryPostCode=M1+7QW&CustomerEMail=tekin%40tekin.co.uk&ClientIPAddress=86.150.65.37&Vendor=spreedly&TxType=PAYMENT&VPSProtocol=3.00
I, [2015-07-22T17:16:49.292774 #97998]  INFO -- : [ActiveMerchant::Billing::SagePayGateway] --> 200 OK (356 1.8635s)
D, [2015-07-22T17:16:49.292836 #97998] DEBUG -- : VPSProtocol=3.00
Status=OK
StatusDetail=0000 : The Authorisation was Successful.
VPSTxId={D5B43220-E93C-ED13-6643-D22224BD1CDB}
SecurityKey=7OYK4OHM7Y
TxAuthNo=8769237
AVSCV2=DATA NOT CHECKED
AddressResult=NOTPROVIDED
PostCodeResult=NOTPROVIDED
CV2Result=NOTPROVIDED
3DSecureStatus=NOTCHECKED
DeclineCode=00
ExpiryDate=0616
BankAuthCode=999777
  TRANSCRIPT

  end
end
