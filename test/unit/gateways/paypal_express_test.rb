require 'test_helper'
require 'nokogiri'

class PaypalExpressTest < Test::Unit::TestCase
  TEST_REDIRECT_URL        = 'https://www.sandbox.paypal.com/cgi-bin/webscr?cmd=_express-checkout&token=1234567890'
  TEST_REDIRECT_URL_MOBILE = 'https://www.sandbox.paypal.com/cgi-bin/webscr?cmd=_express-checkout-mobile&token=1234567890'
  LIVE_REDIRECT_URL        = 'https://www.paypal.com/cgi-bin/webscr?cmd=_express-checkout&token=1234567890'
  LIVE_REDIRECT_URL_MOBILE = 'https://www.paypal.com/cgi-bin/webscr?cmd=_express-checkout-mobile&token=1234567890'

  TEST_REDIRECT_URL_WITHOUT_REVIEW = "#{TEST_REDIRECT_URL}&useraction=commit"
  LIVE_REDIRECT_URL_WITHOUT_REVIEW = "#{LIVE_REDIRECT_URL}&useraction=commit"
  TEST_REDIRECT_URL_MOBILE_WITHOUT_REVIEW = "#{TEST_REDIRECT_URL_MOBILE}&useraction=commit"
  LIVE_REDIRECT_URL_MOBILE_WITHOUT_REVIEW = "#{LIVE_REDIRECT_URL_MOBILE}&useraction=commit"

  def setup
    @gateway = PaypalExpressGateway.new(
      :login => 'cody',
      :password => 'test',
      :pem => 'PEM'
    )

    @address = { :address1 => '1234 My Street',
                 :address2 => 'Apt 1',
                 :company => 'Widgets Inc',
                 :city => 'Ottawa',
                 :state => 'ON',
                 :zip => 'K1C2N6',
                 :country => 'Canada',
                 :phone => '(555)555-5555'
               }

    Base.mode = :test
  end

  def teardown
    Base.mode = :test
  end

  def test_live_redirect_url
    Base.mode = :production
    assert_equal LIVE_REDIRECT_URL, @gateway.redirect_url_for('1234567890')
    assert_equal LIVE_REDIRECT_URL_MOBILE, @gateway.redirect_url_for('1234567890', :mobile => true)
  end

  def test_live_redirect_url_without_review
    Base.mode = :production
    assert_equal LIVE_REDIRECT_URL_WITHOUT_REVIEW, @gateway.redirect_url_for('1234567890', :review => false)
    assert_equal LIVE_REDIRECT_URL_MOBILE_WITHOUT_REVIEW, @gateway.redirect_url_for('1234567890', :review => false, :mobile => true)
  end

  def test_force_sandbox_redirect_url
    Base.mode = :production

    gateway = PaypalExpressGateway.new(
      :login => 'cody',
      :password => 'test',
      :pem => 'PEM',
      :test => true
    )

    assert gateway.test?
    assert_equal TEST_REDIRECT_URL, gateway.redirect_url_for('1234567890')
    assert_equal TEST_REDIRECT_URL_MOBILE, gateway.redirect_url_for('1234567890', :mobile => true)
  end

  def test_test_redirect_url
    assert_equal :test, Base.mode
    assert_equal TEST_REDIRECT_URL, @gateway.redirect_url_for('1234567890')
    assert_equal TEST_REDIRECT_URL_MOBILE, @gateway.redirect_url_for('1234567890', :mobile => true)
  end

  def test_test_redirect_url_without_review
    assert_equal :test, Base.mode
    assert_equal TEST_REDIRECT_URL_WITHOUT_REVIEW, @gateway.redirect_url_for('1234567890', :review => false)
    assert_equal TEST_REDIRECT_URL_MOBILE_WITHOUT_REVIEW, @gateway.redirect_url_for('1234567890', :review => false, :mobile => true)
  end

  def test_get_express_details
    @gateway.expects(:ssl_post).returns(successful_details_response)
    response = @gateway.details_for('EC-2OPN7UJGFWK9OYFV')

    assert_instance_of PaypalExpressResponse, response
    assert response.success?
    assert response.test?

    assert_equal 'EC-2XE90996XX9870316', response.token
    assert_equal 'FWRVKNRRZ3WUC', response.payer_id
    assert_equal 'buyer@jadedpallet.com', response.email
    assert_equal 'This is a test note', response.note

    assert address = response.address
    assert_equal 'Fred Brooks', address['name']
    assert_nil address['company']
    assert_equal '1234 Penny Lane', address['address1']
    assert_nil address['address2']
    assert_equal 'Jonsetown', address['city']
    assert_equal 'NC', address['state']
    assert_equal '23456', address['zip']
    assert_equal 'US', address['country']
    assert_equal '416-618-9984', address['phone']
    assert shipping = response.shipping
    assert_equal '2.95', shipping['amount']
    assert_equal 'default', shipping['name']
  end

  def test_express_response_missing_address
    response = PaypalExpressResponse.new(true, "ok")
    assert_nil response.address['address1']
  end

  def test_authorization
    @gateway.expects(:ssl_post).returns(successful_authorization_response)
    response = @gateway.authorize(300, :token => 'EC-6WS104951Y388951L', :payer_id => 'FWRVKNRRZ3WUC')
    assert response.success?
    assert_not_nil response.authorization
    assert response.test?
  end

  def test_default_payflow_currency
    assert_equal 'USD', PayflowExpressGateway.default_currency
  end

  def test_default_partner
    assert_equal 'PayPal', PayflowExpressGateway.partner
  end

  def test_uk_partner
    assert_equal 'PayPalUk', PayflowExpressUkGateway.partner
  end

  def test_includes_description
    xml = REXML::Document.new(@gateway.send(:build_setup_request, 'SetExpressCheckout', 0, { :description => 'a description' }))

    assert_equal 'a description', REXML::XPath.first(xml, '//n2:PaymentDetails/n2:OrderDescription').text
  end

  def test_includes_order_id
    xml = REXML::Document.new(@gateway.send(:build_setup_request, 'SetExpressCheckout', 0, { :order_id => '12345' }))

    assert_equal '12345', REXML::XPath.first(xml, '//n2:PaymentDetails/n2:InvoiceID').text
  end

  def test_includes_correct_payment_action
    xml = REXML::Document.new(@gateway.send(:build_setup_request, 'SetExpressCheckout', 0, { }))

    assert_equal 'SetExpressCheckout', REXML::XPath.first(xml, '//n2:PaymentDetails/n2:PaymentAction').text
  end

  def test_includes_custom_tag_if_specified
    xml = REXML::Document.new(@gateway.send(:build_setup_request, 'SetExpressCheckout', 0, {:custom => 'Foo'}))

    assert_equal 'Foo', REXML::XPath.first(xml, '//n2:PaymentDetails/n2:Custom').text
  end

  def test_does_not_include_custom_tag_if_not_specified
    xml = REXML::Document.new(@gateway.send(:build_setup_request, 'SetExpressCheckout', 0, {}))

    assert_nil REXML::XPath.first(xml, '//n2:PaymentDetails/n2:Custom')
  end

  def test_does_not_include_items_if_not_specified
    xml = REXML::Document.new(@gateway.send(:build_setup_request, 'SetExpressCheckout', 0, {}))

    assert_nil REXML::XPath.first(xml, '//n2:PaymentDetails/n2:PaymentDetailsItem')
  end

  def test_items_are_included_if_specified_in_build_setup_request
    xml = REXML::Document.new(@gateway.send(:build_setup_request, 'SetExpressCheckout', 0, {:currency => 'GBP', :items => [
                                            {:name => 'item one', :description => 'item one description', :amount => 10000, :number => 1, :quantity => 3},
                                            {:name => 'item two', :description => 'item two description', :amount => 20000, :number => 2, :quantity => 4}
    ]}))

    assert_equal 'item one', REXML::XPath.first(xml, '//n2:PaymentDetails/n2:PaymentDetailsItem/n2:Name').text
    assert_equal 'item one description', REXML::XPath.first(xml, '//n2:PaymentDetails/n2:PaymentDetailsItem/n2:Description').text
    assert_equal '100.00', REXML::XPath.first(xml, '//n2:PaymentDetails/n2:PaymentDetailsItem/n2:Amount').text
    assert_equal 'GBP', REXML::XPath.first(xml, '//n2:PaymentDetails/n2:PaymentDetailsItem/n2:Amount').attribute('currencyID').value
    assert_equal '1', REXML::XPath.first(xml, '//n2:PaymentDetails/n2:PaymentDetailsItem/n2:Number').text
    assert_equal '3', REXML::XPath.first(xml, '//n2:PaymentDetails/n2:PaymentDetailsItem/n2:Quantity').text

    assert_equal 'item two', REXML::XPath.match(xml, '//n2:PaymentDetails/n2:PaymentDetailsItem/n2:Name')[1].text
    assert_equal 'item two description', REXML::XPath.match(xml, '//n2:PaymentDetails/n2:PaymentDetailsItem/n2:Description')[1].text
    assert_equal '200.00', REXML::XPath.match(xml, '//n2:PaymentDetails/n2:PaymentDetailsItem/n2:Amount')[1].text
    assert_equal 'GBP', REXML::XPath.match(xml, '//n2:PaymentDetails/n2:PaymentDetailsItem/n2:Amount')[1].attribute('currencyID').value
    assert_equal '2', REXML::XPath.match(xml, '//n2:PaymentDetails/n2:PaymentDetailsItem/n2:Number')[1].text
    assert_equal '4', REXML::XPath.match(xml, '//n2:PaymentDetails/n2:PaymentDetailsItem/n2:Quantity')[1].text
  end

  def test_does_not_include_callback_url_if_not_specified
    xml = REXML::Document.new(@gateway.send(:build_setup_request, 'SetExpressCheckout', 0, {}))

    assert_nil REXML::XPath.first(xml, '//n2:CallbackURL')
  end

  def test_callback_url_is_included_if_specified_in_build_setup_request
    xml = REXML::Document.new(@gateway.send(:build_setup_request, 'SetExpressCheckout', 0, {:callback_url => "http://example.com/update_callback"}))

    assert_equal 'http://example.com/update_callback', REXML::XPath.first(xml, '//n2:CallbackURL').text
  end

  def test_does_not_include_callback_timeout_if_not_specified
    xml = REXML::Document.new(@gateway.send(:build_setup_request, 'SetExpressCheckout', 0, {}))

    assert_nil REXML::XPath.first(xml, '//n2:CallbackTimeout')
  end

  def test_callback_timeout_is_included_if_specified_in_build_setup_request
    xml = REXML::Document.new(@gateway.send(:build_setup_request, 'SetExpressCheckout', 0, {:callback_timeout => 2}))

    assert_equal '2', REXML::XPath.first(xml, '//n2:CallbackTimeout').text
  end

  def test_does_not_include_callback_version_if_not_specified
    xml = REXML::Document.new(@gateway.send(:build_setup_request, 'SetExpressCheckout', 0, {}))

    assert_nil REXML::XPath.first(xml, '//n2:CallbackVersion')
  end

  def test_callback_version_is_included_if_specified_in_build_setup_request
    xml = REXML::Document.new(@gateway.send(:build_setup_request, 'SetExpressCheckout', 0, {:callback_version => '53.0'}))

    assert_equal '53.0', REXML::XPath.first(xml, '//n2:CallbackVersion').text
  end

  def test_does_not_include_flatrate_shipping_options_if_not_specified
    xml = REXML::Document.new(@gateway.send(:build_setup_request, 'SetExpressCheckout', 0, {}))

    assert_nil REXML::XPath.first(xml, '//n2:FlatRateShippingOptions')
  end

  def test_flatrate_shipping_options_are_included_if_specified_in_build_setup_request
    xml = REXML::Document.new(@gateway.send(:build_setup_request, 'SetExpressCheckout', 0, {:currency => 'AUD', :shipping_options => [
            {:default => true,
             :name => "first one",
             :amount => 1000
            },
            {:default => false,
             :name => "second one",
             :amount => 2000
            }
    ]}))

    assert_equal 'true', REXML::XPath.first(xml, '//n2:FlatRateShippingOptions/n2:ShippingOptionIsDefault').text
    assert_equal 'first one', REXML::XPath.first(xml, '//n2:FlatRateShippingOptions/n2:ShippingOptionName').text
    assert_equal '10.00', REXML::XPath.first(xml, '//n2:FlatRateShippingOptions/n2:ShippingOptionAmount').text
    assert_equal 'AUD', REXML::XPath.first(xml, '//n2:FlatRateShippingOptions/n2:ShippingOptionAmount').attribute('currencyID').value

    assert_equal 'false', REXML::XPath.match(xml, '//n2:FlatRateShippingOptions/n2:ShippingOptionIsDefault')[1].text
    assert_equal 'second one', REXML::XPath.match(xml, '//n2:FlatRateShippingOptions/n2:ShippingOptionName')[1].text
    assert_equal '20.00', REXML::XPath.match(xml, '//n2:FlatRateShippingOptions/n2:ShippingOptionAmount')[1].text
    assert_equal 'AUD', REXML::XPath.match(xml, '//n2:FlatRateShippingOptions/n2:ShippingOptionAmount')[1].attribute('currencyID').value
  end

  def test_address_is_included_if_specified
    xml = REXML::Document.new(@gateway.send(:build_setup_request, 'Sale', 0, {:currency => 'GBP', :address => {
      :name     => "John Doe",
      :address1 => "123 somewhere",
      :city     => "Townville",
      :country  => "Canada",
      :zip      => "k1l4p2",
      :phone    => "1231231231"
    }}))

    assert_equal 'John Doe', REXML::XPath.first(xml, '//n2:PaymentDetails/n2:ShipToAddress/n2:Name').text
    assert_equal '123 somewhere', REXML::XPath.first(xml, '//n2:PaymentDetails/n2:ShipToAddress/n2:Street1').text
    assert_equal 'Townville', REXML::XPath.first(xml, '//n2:PaymentDetails/n2:ShipToAddress/n2:CityName').text
    assert_equal 'Canada', REXML::XPath.first(xml, '//n2:PaymentDetails/n2:ShipToAddress/n2:Country').text
    assert_equal 'k1l4p2', REXML::XPath.first(xml, '//n2:PaymentDetails/n2:ShipToAddress/n2:PostalCode').text
    assert_equal '1231231231', REXML::XPath.first(xml, '//n2:PaymentDetails/n2:ShipToAddress/n2:Phone').text
  end

  def test_handle_non_zero_amount
    xml = REXML::Document.new(@gateway.send(:build_setup_request, 'SetExpressCheckout', 50, {}))

    assert_equal '0.50', REXML::XPath.first(xml, '//n2:PaymentDetails/n2:OrderTotal').text
  end

  def test_amount_format_for_jpy_currency
    @gateway.expects(:ssl_post).with(anything, regexp_matches(/n2:OrderTotal currencyID=.JPY.>1<\/n2:OrderTotal>/), {}).returns(successful_authorization_response)
    response = @gateway.authorize(100, :token => 'EC-6WS104951Y388951L', :payer_id => 'FWRVKNRRZ3WUC', :currency => 'JPY')
    assert response.success?
  end

  def test_removes_fractional_amounts_with_twd_currency
    xml = REXML::Document.new(@gateway.send(:build_setup_request, 'SetExpressCheckout', 150, {:currency => 'TWD'}))

    assert_equal '1', REXML::XPath.first(xml, '//n2:OrderTotal').text
  end

  def test_fractional_discounts_are_correctly_calculated_with_jpy_currency
    xml = REXML::Document.new(@gateway.send(:build_setup_request, 'SetExpressCheckout', 14250, { :items =>
                            [{:name => 'item one', :description => 'description', :amount => 15000, :number => 1, :quantity => 1},
                             {:name => 'Discount', :description => 'Discount', :amount => -750, :number => 2, :quantity => 1}],
                             :subtotal => 14250, :currency => 'JPY', :shipping => 0, :handling => 0, :tax => 0 }))

    assert_equal '142', REXML::XPath.first(xml, '//n2:OrderTotal').text
    assert_equal '142', REXML::XPath.first(xml, '//n2:ItemTotal').text
    amounts = REXML::XPath.match(xml, '//n2:Amount')
    assert_equal '150', amounts[0].text
    assert_equal '-8', amounts[1].text
  end

  def test_non_fractional_discounts_are_correctly_calculated_with_jpy_currency
    xml = REXML::Document.new(@gateway.send(:build_setup_request, 'SetExpressCheckout', 14300, { :items =>
                            [{:name => 'item one', :description => 'description', :amount => 15000, :number => 1, :quantity => 1},
                             {:name => 'Discount', :description => 'Discount', :amount => -700, :number => 2, :quantity => 1}],
                             :subtotal => 14300, :currency => 'JPY', :shipping => 0, :handling => 0, :tax => 0 }))

    assert_equal '143', REXML::XPath.first(xml, '//n2:OrderTotal').text
    assert_equal '143', REXML::XPath.first(xml, '//n2:ItemTotal').text
    amounts = REXML::XPath.match(xml, '//n2:Amount')
    assert_equal '150', amounts[0].text
    assert_equal '-7', amounts[1].text
  end

  def test_fractional_discounts_are_correctly_calculated_with_usd_currency
    xml = REXML::Document.new(@gateway.send(:build_setup_request, 'SetExpressCheckout', 14250, { :items =>
                            [{:name => 'item one', :description => 'description', :amount => 15000, :number => 1, :quantity => 1},
                             {:name => 'Discount', :description => 'Discount', :amount => -750, :number => 2, :quantity => 1}],
                             :subtotal => 14250, :currency => 'USD', :shipping => 0, :handling => 0, :tax => 0 }))

    assert_equal '142.50', REXML::XPath.first(xml, '//n2:OrderTotal').text
    assert_equal '142.50', REXML::XPath.first(xml, '//n2:ItemTotal').text
    amounts = REXML::XPath.match(xml, '//n2:Amount')
    assert_equal '150.00', amounts[0].text
    assert_equal '-7.50', amounts[1].text
  end

  def test_does_not_add_allow_note_if_not_specified
    xml = REXML::Document.new(@gateway.send(:build_setup_request, 'SetExpressCheckout', 0, { }))

    assert_nil REXML::XPath.first(xml, '//n2:AllowNote')
  end

  def test_adds_allow_note_if_specified
    allow_notes_xml = REXML::Document.new(@gateway.send(:build_setup_request, 'SetExpressCheckout', 0, { :allow_note => true }))
    do_not_allow_notes_xml = REXML::Document.new(@gateway.send(:build_setup_request, 'SetExpressCheckout', 0, { :allow_note => false }))

    assert_equal '1', REXML::XPath.first(allow_notes_xml, '//n2:AllowNote').text
    assert_equal '0', REXML::XPath.first(do_not_allow_notes_xml, '//n2:AllowNote').text
  end

  def test_handle_locale_code
    xml = REXML::Document.new(@gateway.send(:build_setup_request, 'SetExpressCheckout', 0, { :locale => 'GB' }))

    assert_equal 'GB', REXML::XPath.first(xml, '//n2:LocaleCode').text
  end

  def test_handle_non_standard_locale_code
    xml = REXML::Document.new(@gateway.send(:build_setup_request, 'SetExpressCheckout', 0, { :locale => 'IL' }))

    assert_equal 'he_IL', REXML::XPath.first(xml, '//n2:LocaleCode').text
  end

  def test_does_not_include_locale_in_request_unless_provided_in_options
    xml = REXML::Document.new(@gateway.send(:build_setup_request, 'SetExpressCheckout', 0, { :locale => nil }))

    assert_nil REXML::XPath.first(xml, '//n2:LocaleCode')
  end

  def test_supported_countries
    assert_equal ['US'], PaypalExpressGateway.supported_countries
  end

  def test_button_source
    PaypalExpressGateway.application_id = 'ActiveMerchant_EC'

    xml = REXML::Document.new(@gateway.send(:build_sale_or_authorization_request, 'Test', 100, {}))
    assert_equal 'ActiveMerchant_EC', REXML::XPath.first(xml, '//n2:ButtonSource').text
  end

  def test_items_are_included_if_specified_in_build_sale_or_authorization_request
    xml = REXML::Document.new(@gateway.send(:build_sale_or_authorization_request, 'Sale', 100, {:items => [
                                            {:name => 'item one', :description => 'item one description', :amount => 10000, :number => 1, :quantity => 3},
                                            {:name => 'item two', :description => 'item two description', :amount => 20000, :number => 2, :quantity => 4}
    ]}))


    assert_equal 'item one', REXML::XPath.first(xml, '//n2:PaymentDetails/n2:PaymentDetailsItem/n2:Name').text
    assert_equal 'item one description', REXML::XPath.first(xml, '//n2:PaymentDetails/n2:PaymentDetailsItem/n2:Description').text
    assert_equal '100.00', REXML::XPath.first(xml, '//n2:PaymentDetails/n2:PaymentDetailsItem/n2:Amount').text
    assert_equal '1', REXML::XPath.first(xml, '//n2:PaymentDetails/n2:PaymentDetailsItem/n2:Number').text
    assert_equal '3', REXML::XPath.first(xml, '//n2:PaymentDetails/n2:PaymentDetailsItem/n2:Quantity').text

    assert_equal 'item two', REXML::XPath.match(xml, '//n2:PaymentDetails/n2:PaymentDetailsItem/n2:Name')[1].text
    assert_equal 'item two description', REXML::XPath.match(xml, '//n2:PaymentDetails/n2:PaymentDetailsItem/n2:Description')[1].text
    assert_equal '200.00', REXML::XPath.match(xml, '//n2:PaymentDetails/n2:PaymentDetailsItem/n2:Amount')[1].text
    assert_equal '2', REXML::XPath.match(xml, '//n2:PaymentDetails/n2:PaymentDetailsItem/n2:Number')[1].text
    assert_equal '4', REXML::XPath.match(xml, '//n2:PaymentDetails/n2:PaymentDetailsItem/n2:Quantity')[1].text
  end

  def test_build_create_billing_agreement
    PaypalExpressGateway.application_id = 'ActiveMerchant_FOO'
    xml = REXML::Document.new(@gateway.send(:build_create_billing_agreement_request, "ref_id"))

    assert_equal 'ref_id', REXML::XPath.first(xml, '//CreateBillingAgreementReq/CreateBillingAgreementRequest/Token').text
  end

  def test_store
    @gateway.expects(:ssl_post).returns(successful_create_billing_agreement_response)

    response = @gateway.store("ref_id")

    assert_equal "Success", response.params['ack']
    assert_equal "Success", response.message
    assert_equal "B-3R788221G4476823M", response.params["billing_agreement_id"]
  end

  def test_unstore_successful
    @gateway.expects(:ssl_post).returns(successful_cancel_billing_agreement_response)
    response = @gateway.unstore("B-3RU433629T663020S")

    assert response.success?
    assert_equal "Success", response.params['ack']
    assert_equal "Success", response.message
    assert_equal "B-3RU433629T663020S", response.params["billing_agreement_id"]
    assert_equal "Canceled", response.params["billing_agreement_status"]
  end

  def test_unstore_failed
    @gateway.expects(:ssl_post).returns(failed_cancel_billing_agreement_response)
    response = @gateway.unstore("B-3RU433629T663020S")

    assert !response.success?
    assert_equal "Failure", response.params['ack']
    assert_equal "Billing Agreement was cancelled", response.message
    assert_equal "10201", response.params["error_codes"]
  end

  def test_agreement_details_successful
    @gateway.expects(:ssl_post).returns(successful_billing_agreement_details_response)
    response = @gateway.agreement_details("B-6VE21702A47915521")

    assert response.success?
    assert_equal "Success", response.params['ack']
    assert_equal "Success", response.message
    assert_equal "B-6VE21702A47915521", response.params["billing_agreement_id"]
    assert_equal "Active", response.params["billing_agreement_status"]
  end

  def test_agreement_details_failure
    @gateway.expects(:ssl_post).returns(failure_billing_agreement_details_response)
    response = @gateway.agreement_details("bad_reference_id")

    assert !response.success?
    assert_equal "Failure", response.params['ack']
    assert_equal "Billing Agreement Id or transaction Id is not valid", response.message
    assert_equal "11451", response.params["error_codes"]
  end


  def test_build_reference_transaction_test
    PaypalExpressGateway.application_id = 'ActiveMerchant_FOO'
    xml = REXML::Document.new(@gateway.send(:build_reference_transaction_request, 'Sale', 2000, {
      :reference_id => "ref_id",
      :payment_type => 'Any',
      :invoice_id   => 'invoice_id',
      :description  => 'Description',
      :ip           => '127.0.0.1' }))

    assert_equal '124', REXML::XPath.first(xml, '//DoReferenceTransactionReq/DoReferenceTransactionRequest/n2:Version').text
    assert_equal 'ref_id', REXML::XPath.first(xml, '//DoReferenceTransactionReq/DoReferenceTransactionRequest/n2:DoReferenceTransactionRequestDetails/n2:ReferenceID').text
    assert_equal 'Sale', REXML::XPath.first(xml, '//DoReferenceTransactionReq/DoReferenceTransactionRequest/n2:DoReferenceTransactionRequestDetails/n2:PaymentAction').text
    assert_equal 'Any', REXML::XPath.first(xml, '//DoReferenceTransactionReq/DoReferenceTransactionRequest/n2:DoReferenceTransactionRequestDetails/n2:PaymentType').text
    assert_equal '20.00', REXML::XPath.first(xml, '//DoReferenceTransactionReq/DoReferenceTransactionRequest/n2:DoReferenceTransactionRequestDetails/n2:PaymentDetails/n2:OrderTotal').text
    assert_equal 'Description', REXML::XPath.first(xml, '//DoReferenceTransactionReq/DoReferenceTransactionRequest/n2:DoReferenceTransactionRequestDetails/n2:PaymentDetails/n2:OrderDescription').text
    assert_equal 'invoice_id', REXML::XPath.first(xml, '//DoReferenceTransactionReq/DoReferenceTransactionRequest/n2:DoReferenceTransactionRequestDetails/n2:PaymentDetails/n2:InvoiceID').text
    assert_equal 'ActiveMerchant_FOO', REXML::XPath.first(xml, '//DoReferenceTransactionReq/DoReferenceTransactionRequest/n2:DoReferenceTransactionRequestDetails/n2:PaymentDetails/n2:ButtonSource').text
    assert_equal '127.0.0.1', REXML::XPath.first(xml, '//DoReferenceTransactionReq/DoReferenceTransactionRequest/n2:DoReferenceTransactionRequestDetails/n2:IPAddress').text
  end

  def test_build_details_billing_agreement_request_test
    xml = REXML::Document.new(@gateway.send(:build_details_billing_agreement_request, 'reference_ID'))
    assert_equal 'reference_ID', REXML::XPath.first(xml, '//BillAgreementUpdateReq/BAUpdateRequest/ReferenceID').text
    assert_nil REXML::XPath.first(xml, '//BillAgreementUpdateReq/BAUpdateRequest/BillingAgreementStatus')
  end

  def test_authorize_reference_transaction
    @gateway.expects(:ssl_post).returns(successful_authorize_reference_transaction_response)

    response = @gateway.authorize_reference_transaction(2000,  {
      :reference_id => "ref_id",
      :payment_type => 'Any',
      :invoice_id   => 'invoice_id',
      :description  => 'Description',
      :ip           => '127.0.0.1' })

    assert_equal "Success", response.params['ack']
    assert_equal "Success", response.message
    assert_equal "9R43552341412482K", response.authorization
  end

  def test_reference_transaction
    @gateway.expects(:ssl_post).returns(successful_reference_transaction_response)

    response = @gateway.reference_transaction(2000,  { :reference_id => "ref_id" })

    assert_equal "Success", response.params['ack']
    assert_equal "Success", response.message
    assert_equal "9R43552341412482K", response.authorization
  end

  def test_reference_transaction_requires_fields
    assert_raise ArgumentError do
      @gateway.reference_transaction(2000, {})
    end
  end

  def test_error_code_for_single_error
    @gateway.expects(:ssl_post).returns(response_with_error)
    response = @gateway.setup_authorization(100,
                 :return_url => 'http://example.com',
                 :cancel_return_url => 'http://example.com'
               )
    assert_equal "10736", response.params['error_codes']
  end

  def test_ensure_only_unique_error_codes
    @gateway.expects(:ssl_post).returns(response_with_duplicate_errors)
    response = @gateway.setup_authorization(100,
                 :return_url => 'http://example.com',
                 :cancel_return_url => 'http://example.com'
               )

    assert_equal "10736" , response.params['error_codes']
  end

  def test_error_codes_for_multiple_errors
    @gateway.expects(:ssl_post).returns(response_with_errors)
    response = @gateway.setup_authorization(100,
                 :return_url => 'http://example.com',
                 :cancel_return_url => 'http://example.com'
               )

    assert_equal ["10736", "10002"] , response.params['error_codes'].split(',')
  end

  def test_allow_guest_checkout
    xml = REXML::Document.new(@gateway.send(:build_setup_request, 'SetExpressCheckout', 10, {:allow_guest_checkout => true}))

    assert_equal 'Sole', REXML::XPath.first(xml, '//n2:SolutionType').text
    assert_equal 'Billing', REXML::XPath.first(xml, '//n2:LandingPage').text
  end

  def test_not_adds_brand_name_if_not_specified
    xml = REXML::Document.new(@gateway.send(:build_setup_request, 'SetExpressCheckout', 10, {}))

    assert_nil REXML::XPath.first(xml, '//n2:BrandName')
  end

  def test_adds_brand_name_if_specified
    xml = REXML::Document.new(@gateway.send(:build_setup_request, 'SetExpressCheckout', 10, {:brand_name => 'Acme'}))
    assert_equal 'Acme', REXML::XPath.first(xml, '//n2:BrandName').text
  end

  def test_get_phone_number_from_address_if_contact_phone_not_sent
    response = successful_details_response.sub(%r{<ContactPhone>416-618-9984</ContactPhone>\n}, '')
    @gateway.expects(:ssl_post).returns(response)
    response = @gateway.details_for('EC-2OPN7UJGFWK9OYFV')
    assert address = response.address
    assert_equal '123-456-7890', address['phone']
  end

  def test_not_adds_buyer_optin_if_not_specified
    xml = REXML::Document.new(@gateway.send(:build_setup_request, 'SetExpressCheckout', 10, {}))
    assert_nil REXML::XPath.first(xml, '//n2:BuyerEmailOptInEnable')
  end

  def test_adds_buyer_optin_if_specified
    allow_optin_xml = REXML::Document.new(@gateway.send(:build_setup_request, 'SetExpressCheckout', 10, {:allow_buyer_optin => true}))
    do_not_allow_optin_xml = REXML::Document.new(@gateway.send(:build_setup_request, 'SetExpressCheckout', 10, {:allow_buyer_optin => false}))

    assert_equal '1', REXML::XPath.first(allow_optin_xml, '//n2:BuyerEmailOptInEnable').text
    assert_equal '0', REXML::XPath.first(do_not_allow_optin_xml, '//n2:BuyerEmailOptInEnable').text
  end

  def test_add_total_type_if_specified
    total_type_xml = REXML::Document.new(@gateway.send(:build_setup_request, 'SetExpressCheckout', 10, {:total_type => 'EstimatedTotal'}))
    no_total_type_xml = REXML::Document.new(@gateway.send(:build_setup_request, 'SetExpressCheckout', 10, {}))

    assert_equal 'EstimatedTotal', REXML::XPath.first(total_type_xml, '//n2:TotalType').text
    assert_nil REXML::XPath.first(no_total_type_xml, '//n2:BuyerEmailOptInEnable')
  end

  def test_structure_correct
    all_options_enabled = {
        :allow_guest_checkout => true,
        :max_amount => 50,
        :locale => 'AU',
        :page_style => 'test-gray',
        :header_image => 'https://example.com/my_business',
        :header_background_color => 'CAFE00',
        :header_border_color => 'CAFE00',
        :background_color => 'CAFE00',
        :email => 'joe@example.com',
        :billing_agreement => {:type => 'MerchantInitiatedBilling', :description => '9.99 per month for a year'},
        :allow_note => true,
        :allow_buyer_optin => true,
        :subtotal => 35,
        :shipping => 10,
        :handling => 0,
        :tax => 5,
        :total_type => 'EstimatedTotal',
        :items => [{:name => 'item one',
                    :number => 'number 1',
                    :quantity => 3,
                    :amount => 35,
                    :description => 'one description',
                    :url => 'http://example.com/number_1'}],
        :address => {:name => 'John Doe',
                     :address1 => 'Apartment 1',
                     :address2 => '1 Road St',
                     :city => 'First City',
                     :state => 'NSW',
                     :country => 'AU',
                     :zip => '2000',
                     :phone => '555 5555'},
        :callback_url => "http://example.com/update_callback",
        :callback_timeout => 2,
        :callback_version => '53.0',
        :funding_sources => {:source => 'BML'},
        :shipping_options => [{:default => true,
                               :name => "first one",
                               :amount => 10}]
    }

    doc = Nokogiri::XML(@gateway.send(:build_setup_request, 'Sale', 10, all_options_enabled))
    #Strip back to the SetExpressCheckoutRequestDetails element - this is where the base component xsd starts
    xml = doc.xpath('//base:SetExpressCheckoutRequestDetails', 'base' => 'urn:ebay:apis:eBLBaseComponents').first
    sub_doc = Nokogiri::XML::Document.new
    sub_doc.root = xml

    schema = Nokogiri::XML::Schema(File.read(File.join(File.dirname(__FILE__), '..', '..', 'schema', 'paypal', 'eBLBaseComponents.xsd')))
    assert_equal [], schema.validate(sub_doc)
  end

  private

  def successful_create_billing_agreement_response
    <<-RESPONSE
<?xml version="1.0" encoding="UTF-8"?>
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:cc="urn:ebay:apis:CoreComponentTypes" xmlns:wsu="http://schemas.xmlsoap.org/ws/2002/07/utility" xmlns:saml="urn:oasis:names:tc:SAML:1.0:assertion" xmlns:ds="http://www.w3.org/2000/09/xmldsig#" xmlns:wsse="http://schemas.xmlsoap.org/ws/2002/12/secext" xmlns:ed="urn:ebay:apis:EnhancedDataTypes" xmlns:ebl="urn:ebay:apis:eBLBaseComponents" xmlns:ns="urn:ebay:api:PayPalAPI">
  <SOAP-ENV:Header>
    <Security xmlns="http://schemas.xmlsoap.org/ws/2002/12/secext" xsi:type="wsse:SecurityType">
  </Security>
    <RequesterCredentials xmlns="urn:ebay:api:PayPalAPI" xsi:type="ebl:CustomSecurityHeaderType">
      <Credentials xmlns="urn:ebay:apis:eBLBaseComponents" xsi:type="ebl:UserIdPasswordType">
        <Username xsi:type="xs:string"></Username>
        <Password xsi:type="xs:string"></Password>
        <Signature xsi:type="xs:string">OMGOMGOMG</Signature>
        <Subject xsi:type="xs:string"></Subject>
    </Credentials>
  </RequesterCredentials>
</SOAP-ENV:Header>
  <SOAP-ENV:Body id="_0">
    <CreateBillingAgreementResponse xmlns="urn:ebay:api:PayPalAPI">
      <Timestamp xmlns="urn:ebay:apis:eBLBaseComponents">2013-02-28T16:34:47Z</Timestamp>
      <Ack xmlns="urn:ebay:apis:eBLBaseComponents">Success</Ack>
      <CorrelationID xmlns="urn:ebay:apis:eBLBaseComponents">8007ac99c51af</CorrelationID>
      <Version xmlns="urn:ebay:apis:eBLBaseComponents">72</Version>
      <Build xmlns="urn:ebay:apis:eBLBaseComponents">5331358</Build>
      <BillingAgreementID xsi:type="xs:string">B-3R788221G4476823M</BillingAgreementID>
    </CreateBillingAgreementResponse>
  </SOAP-ENV:Body>
</SOAP-ENV:Envelope>

    RESPONSE
  end


  def successful_authorize_reference_transaction_response
  <<-RESPONSE
<?xml version="1.0" encoding="UTF-8"?>
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:cc="urn:ebay:apis:CoreComponentTypes" xmlns:wsu="http://schemas.xmlsoap.org/ws/2002/07/utility" xmlns:saml="urn:oasis:names:tc:SAML:1.0:assertion" xmlns:ds="http://www.w3.org/2000/09/xmldsig#" xmlns:wsse="http://schemas.xmlsoap.org/ws/2002/12/secext" xmlns:ed="urn:ebay:apis:EnhancedDataTypes" xmlns:ebl="urn:ebay:apis:eBLBaseComponents" xmlns:ns="urn:ebay:api:PayPalAPI">
  <SOAP-ENV:Header>
    <Security xmlns="http://schemas.xmlsoap.org/ws/2002/12/secext" xsi:type="wsse:SecurityType"></Security>
    <RequesterCredentials xmlns="urn:ebay:api:PayPalAPI" xsi:type="ebl:CustomSecurityHeaderType">
      <Credentials xmlns="urn:ebay:apis:eBLBaseComponents" xsi:type="ebl:UserIdPasswordType">
        <Username xsi:type="xs:string"></Username>
        <Password xsi:type="xs:string"></Password>
        <Signature xsi:type="xs:string">OMGOMGOMG</Signature>
        <Subject xsi:type="xs:string"></Subject>
        </Credentials>
      </RequesterCredentials>
    </SOAP-ENV:Header>
  <SOAP-ENV:Body id="_0">
    <DoReferenceTransactionResponse xmlns="urn:ebay:api:PayPalAPI">
      <Timestamp xmlns="urn:ebay:apis:eBLBaseComponents">2011-05-23T21:36:32Z</Timestamp>
      <Ack xmlns="urn:ebay:apis:eBLBaseComponents">Success</Ack>
      <CorrelationID xmlns="urn:ebay:apis:eBLBaseComponents">4d6d3af55369b</CorrelationID>
      <Version xmlns="urn:ebay:apis:eBLBaseComponents">72</Version>
      <Build xmlns="urn:ebay:apis:eBLBaseComponents">1863577</Build>
      <DoReferenceTransactionResponseDetails xmlns="urn:ebay:apis:eBLBaseComponents" xsi:type="ebl:DoReferenceTransactionResponseDetailsType">
        <BillingAgreementID xsi:type="xs:string">B-3R788221G4476823M</BillingAgreementID>
        <PaymentInfo xsi:type="ebl:PaymentInfoType">
          <TransactionID>9R43552341412482K</TransactionID>
          <ParentTransactionID xsi:type="ebl:TransactionId"></ParentTransactionID>
          <ReceiptID></ReceiptID>
          <TransactionType xsi:type="ebl:PaymentTransactionCodeType">mercht-pmt</TransactionType>
          <PaymentType xsi:type="ebl:PaymentCodeType">instant</PaymentType>
          <PaymentDate xsi:type="xs:dateTime">2011-05-23T21:36:32Z</PaymentDate>
          <GrossAmount xsi:type="cc:BasicAmountType" currencyID="USD">190.00</GrossAmount>
          <FeeAmount xsi:type="cc:BasicAmountType" currencyID="USD">5.81</FeeAmount>
          <TaxAmount xsi:type="cc:BasicAmountType" currencyID="USD">0.00</TaxAmount>
          <ExchangeRate xsi:type="xs:string"></ExchangeRate>
          <PaymentStatus xsi:type="ebl:PaymentStatusCodeType">Completed</PaymentStatus>
          <PendingReason xsi:type="ebl:PendingStatusCodeType">none</PendingReason>
          <ReasonCode xsi:type="ebl:ReversalReasonCodeType">none</ReasonCode>
          <ProtectionEligibility xsi:type="xs:string">Ineligible</ProtectionEligibility>
          <ProtectionEligibilityType xsi:type="xs:string">None</ProtectionEligibilityType>
          </PaymentInfo>
        </DoReferenceTransactionResponseDetails>
      </DoReferenceTransactionResponse>
    </SOAP-ENV:Body>
  </SOAP-ENV:Envelope>
    RESPONSE
  end

  def successful_reference_transaction_response
    <<-RESPONSE
<?xml version="1.0" encoding="UTF-8"?>
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:cc="urn:ebay:apis:CoreComponentTypes" xmlns:wsu="http://schemas.xmlsoap.org/ws/2002/07/utility" xmlns:saml="urn:oasis:names:tc:SAML:1.0:assertion" xmlns:ds="http://www.w3.org/2000/09/xmldsig#" xmlns:wsse="http://schemas.xmlsoap.org/ws/2002/12/secext" xmlns:ed="urn:ebay:apis:EnhancedDataTypes" xmlns:ebl="urn:ebay:apis:eBLBaseComponents" xmlns:ns="urn:ebay:api:PayPalAPI">
	<SOAP-ENV:Header>
		<Security xmlns="http://schemas.xmlsoap.org/ws/2002/12/secext" xsi:type="wsse:SecurityType"></Security>
		<RequesterCredentials xmlns="urn:ebay:api:PayPalAPI" xsi:type="ebl:CustomSecurityHeaderType">
			<Credentials xmlns="urn:ebay:apis:eBLBaseComponents" xsi:type="ebl:UserIdPasswordType">
				<Username xsi:type="xs:string"></Username>
				<Password xsi:type="xs:string"></Password>
				<Signature xsi:type="xs:string">OMGOMGOMG</Signature>
				<Subject xsi:type="xs:string"></Subject>
				</Credentials>
			</RequesterCredentials>
		</SOAP-ENV:Header>
	<SOAP-ENV:Body id="_0">
		<DoReferenceTransactionResponse xmlns="urn:ebay:api:PayPalAPI">
			<Timestamp xmlns="urn:ebay:apis:eBLBaseComponents">2011-05-23T21:36:32Z</Timestamp>
			<Ack xmlns="urn:ebay:apis:eBLBaseComponents">Success</Ack>
			<CorrelationID xmlns="urn:ebay:apis:eBLBaseComponents">4d6d3af55369b</CorrelationID>
			<Version xmlns="urn:ebay:apis:eBLBaseComponents">72</Version>
			<Build xmlns="urn:ebay:apis:eBLBaseComponents">1863577</Build>
			<DoReferenceTransactionResponseDetails xmlns="urn:ebay:apis:eBLBaseComponents" xsi:type="ebl:DoReferenceTransactionResponseDetailsType">
				<BillingAgreementID xsi:type="xs:string">B-3R788221G4476823M</BillingAgreementID>
				<PaymentInfo xsi:type="ebl:PaymentInfoType">
					<TransactionID>9R43552341412482K</TransactionID>
					<ParentTransactionID xsi:type="ebl:TransactionId"></ParentTransactionID>
					<ReceiptID></ReceiptID>
					<TransactionType xsi:type="ebl:PaymentTransactionCodeType">mercht-pmt</TransactionType>
					<PaymentType xsi:type="ebl:PaymentCodeType">instant</PaymentType>
					<PaymentDate xsi:type="xs:dateTime">2011-05-23T21:36:32Z</PaymentDate>
					<GrossAmount xsi:type="cc:BasicAmountType" currencyID="USD">190.00</GrossAmount>
					<FeeAmount xsi:type="cc:BasicAmountType" currencyID="USD">5.81</FeeAmount>
					<TaxAmount xsi:type="cc:BasicAmountType" currencyID="USD">0.00</TaxAmount>
					<ExchangeRate xsi:type="xs:string"></ExchangeRate>
					<PaymentStatus xsi:type="ebl:PaymentStatusCodeType">Completed</PaymentStatus>
					<PendingReason xsi:type="ebl:PendingStatusCodeType">none</PendingReason>
					<ReasonCode xsi:type="ebl:ReversalReasonCodeType">none</ReasonCode>
					<ProtectionEligibility xsi:type="xs:string">Ineligible</ProtectionEligibility>
					<ProtectionEligibilityType xsi:type="xs:string">None</ProtectionEligibilityType>
					</PaymentInfo>
				</DoReferenceTransactionResponseDetails>
			</DoReferenceTransactionResponse>
		</SOAP-ENV:Body>
	</SOAP-ENV:Envelope>
    RESPONSE
  end


  def successful_details_response
    <<-RESPONSE
<?xml version="1.0" encoding="UTF-8"?>
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:cc="urn:ebay:apis:CoreComponentTypes" xmlns:wsu="http://schemas.xmlsoap.org/ws/2002/07/utility" xmlns:saml="urn:oasis:names:tc:SAML:1.0:assertion" xmlns:ds="http://www.w3.org/2000/09/xmldsig#" xmlns:wsse="http://schemas.xmlsoap.org/ws/2002/12/secext" xmlns:ed="urn:ebay:apis:EnhancedDataTypes" xmlns:ebl="urn:ebay:apis:eBLBaseComponents" xmlns:ns="urn:ebay:api:PayPalAPI">
  <SOAP-ENV:Header>
    <Security xmlns="http://schemas.xmlsoap.org/ws/2002/12/secext" xsi:type="wsse:SecurityType"/>
    <RequesterCredentials xmlns="urn:ebay:api:PayPalAPI" xsi:type="ebl:CustomSecurityHeaderType">
      <Credentials xmlns="urn:ebay:apis:eBLBaseComponents" xsi:type="ebl:UserIdPasswordType">
        <Username xsi:type="xs:string"/>
        <Password xsi:type="xs:string"/>
        <Signature xsi:type="xs:string" />
        <Subject xsi:type="xs:string"/>
      </Credentials>
    </RequesterCredentials>
  </SOAP-ENV:Header>
  <SOAP-ENV:Body id="_0">
    <GetExpressCheckoutDetailsResponse xmlns="urn:ebay:api:PayPalAPI">
      <Timestamp xmlns="urn:ebay:apis:eBLBaseComponents">2011-03-01T20:19:35Z</Timestamp>
      <Ack xmlns="urn:ebay:apis:eBLBaseComponents">Success</Ack>
      <CorrelationID xmlns="urn:ebay:apis:eBLBaseComponents">84aff0e17b6f</CorrelationID>
      <Version xmlns="urn:ebay:apis:eBLBaseComponents">62.0</Version>
      <Build xmlns="urn:ebay:apis:eBLBaseComponents">1741654</Build>
      <GetExpressCheckoutDetailsResponseDetails xmlns="urn:ebay:apis:eBLBaseComponents" xsi:type="ebl:GetExpressCheckoutDetailsResponseDetailsType">
        <Token xsi:type="ebl:ExpressCheckoutTokenType">EC-2XE90996XX9870316</Token>
        <PayerInfo xsi:type="ebl:PayerInfoType">
          <Payer xsi:type="ebl:EmailAddressType">buyer@jadedpallet.com</Payer>
          <PayerID xsi:type="ebl:UserIDType">FWRVKNRRZ3WUC</PayerID>
          <PayerStatus xsi:type="ebl:PayPalUserStatusCodeType">verified</PayerStatus>
          <PayerName xsi:type='ebl:PersonNameType'>
            <Salutation xmlns='urn:ebay:apis:eBLBaseComponents'/>
            <FirstName xmlns='urn:ebay:apis:eBLBaseComponents'>Fred</FirstName>
            <MiddleName xmlns='urn:ebay:apis:eBLBaseComponents'/>
            <LastName xmlns='urn:ebay:apis:eBLBaseComponents'>Brooks</LastName>
            <Suffix xmlns='urn:ebay:apis:eBLBaseComponents'/>
          </PayerName>
          <PayerCountry xsi:type="ebl:CountryCodeType">US</PayerCountry>
          <PayerBusiness xsi:type="xs:string"/>
          <Address xsi:type="ebl:AddressType">
            <Name xsi:type="xs:string">Fred Brooks</Name>
            <Street1 xsi:type="xs:string">1 Infinite Loop</Street1>
            <Street2 xsi:type="xs:string"/>
            <CityName xsi:type="xs:string">Cupertino</CityName>
            <StateOrProvince xsi:type="xs:string">CA</StateOrProvince>
            <Country xsi:type="ebl:CountryCodeType">US</Country>
            <CountryName>United States</CountryName>
            <PostalCode xsi:type="xs:string">95014</PostalCode>
            <AddressOwner xsi:type="ebl:AddressOwnerCodeType">PayPal</AddressOwner>
            <AddressStatus xsi:type="ebl:AddressStatusCodeType">Confirmed</AddressStatus>
          </Address>
        </PayerInfo>
        <InvoiceID xsi:type="xs:string">1230123</InvoiceID>
        <ContactPhone>416-618-9984</ContactPhone>
        <PaymentDetails xsi:type="ebl:PaymentDetailsType">
          <OrderTotal xsi:type="cc:BasicAmountType" currencyID="USD">19.00</OrderTotal>
          <ItemTotal xsi:type="cc:BasicAmountType" currencyID="USD">19.00</ItemTotal>
          <ShippingTotal xsi:type="cc:BasicAmountType" currencyID="USD">0.00</ShippingTotal>
          <HandlingTotal xsi:type="cc:BasicAmountType" currencyID="USD">0.00</HandlingTotal>
          <TaxTotal xsi:type="cc:BasicAmountType" currencyID="USD">0.00</TaxTotal>
          <ShipToAddress xsi:type="ebl:AddressType">
            <Name xsi:type="xs:string">Fred Brooks</Name>
            <Street1 xsi:type="xs:string">1234 Penny Lane</Street1>
            <Street2 xsi:type="xs:string"/>
            <CityName xsi:type="xs:string">Jonsetown</CityName>
            <StateOrProvince xsi:type="xs:string">NC</StateOrProvince>
            <Country xsi:type="ebl:CountryCodeType">US</Country>
            <CountryName>United States</CountryName>
            <Phone xsi:type="xs:string">123-456-7890</Phone>
            <PostalCode xsi:type="xs:string">23456</PostalCode>
            <AddressID xsi:type="xs:string"/>
            <AddressOwner xsi:type="ebl:AddressOwnerCodeType">PayPal</AddressOwner>
            <ExternalAddressID xsi:type="xs:string"/>
            <AddressStatus xsi:type="ebl:AddressStatusCodeType">Confirmed</AddressStatus>
          </ShipToAddress>
          <PaymentDetailsItem xmlns="urn:ebay:apis:eBLBaseComponents" xsi:type="ebl:PaymentDetailsItemType">
            <Name xsi:type="xs:string">Shopify T-Shirt</Name>
            <Quantity>1</Quantity>
            <Tax xsi:type="cc:BasicAmountType" currencyID="USD">0.00</Tax>
            <Amount xsi:type="cc:BasicAmountType" currencyID="USD">19.00</Amount>
            <EbayItemPaymentDetailsItem xmlns="urn:ebay:apis:eBLBaseComponents" xsi:type="ebl:EbayItemPaymentDetailsItemType"/>
          </PaymentDetailsItem>
          <InsuranceTotal xsi:type="cc:BasicAmountType" currencyID="USD">0.00</InsuranceTotal>
          <ShippingDiscount xsi:type="cc:BasicAmountType" currencyID="USD">0.00</ShippingDiscount>
          <InsuranceOptionOffered xsi:type="xs:string">false</InsuranceOptionOffered>
          <NoteText xsi:type="xs:string">This is a test note</NoteText>
          <SellerDetails xsi:type="ebl:SellerDetailsType"/>
          <PaymentRequestID xsi:type="xs:string"/>
          <OrderURL xsi:type="xs:string"/>
          <SoftDescriptor xsi:type="xs:string"/>
        </PaymentDetails>
        <UserSelectedOptions xsi:type=\"ebl:UserSelectedOptionType\">
          <ShippingCalculationMode xsi:type=\"xs:string\">Callback</ShippingCalculationMode>
          <InsuranceOptionSelected xsi:type=\"xs:string\">false</InsuranceOptionSelected>
          <ShippingOptionIsDefault xsi:type=\"xs:string\">true</ShippingOptionIsDefault>
          <ShippingOptionAmount xsi:type=\"cc:BasicAmountType\" currencyID=\"USD\">2.95</ShippingOptionAmount>
          <ShippingOptionName xsi:type=\"xs:string\">default</ShippingOptionName>
        </UserSelectedOptions>
        <CheckoutStatus xsi:type="xs:string">PaymentActionNotInitiated</CheckoutStatus>
        <PaymentRequestInfo xsi:type="ebl:PaymentRequestInfoType" />
      </GetExpressCheckoutDetailsResponseDetails>
    </GetExpressCheckoutDetailsResponse>
  </SOAP-ENV:Body>
</SOAP-ENV:Envelope>
    RESPONSE
  end

  def successful_authorization_response
    <<-RESPONSE
<?xml version='1.0' encoding='UTF-8'?>
<SOAP-ENV:Envelope xmlns:cc='urn:ebay:apis:CoreComponentTypes' xmlns:sizeship='urn:ebay:api:PayPalAPI/sizeship.xsd' xmlns:SOAP-ENV='http://schemas.xmlsoap.org/soap/envelope/' xmlns:SOAP-ENC='http://schemas.xmlsoap.org/soap/encoding/' xmlns:saml='urn:oasis:names:tc:SAML:1.0:assertion' xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' xmlns:wsu='http://schemas.xmlsoap.org/ws/2002/07/utility' xmlns:ebl='urn:ebay:apis:eBLBaseComponents' xmlns:ds='http://www.w3.org/2000/09/xmldsig#' xmlns:xs='http://www.w3.org/2001/XMLSchema' xmlns:ns='urn:ebay:api:PayPalAPI' xmlns:market='urn:ebay:apis:Market' xmlns:ship='urn:ebay:apis:ship' xmlns:auction='urn:ebay:apis:Auction' xmlns:wsse='http://schemas.xmlsoap.org/ws/2002/12/secext' xmlns:xsd='http://www.w3.org/2001/XMLSchema'>
  <SOAP-ENV:Header>
    <Security xsi:type='wsse:SecurityType' xmlns='http://schemas.xmlsoap.org/ws/2002/12/secext'/>
    <RequesterCredentials xsi:type='ebl:CustomSecurityHeaderType' xmlns='urn:ebay:api:PayPalAPI'>
      <Credentials xsi:type='ebl:UserIdPasswordType' xmlns='urn:ebay:apis:eBLBaseComponents'>
        <Username xsi:type='xs:string'/>
        <Password xsi:type='xs:string'/>
        <Subject xsi:type='xs:string'/>
      </Credentials>
    </RequesterCredentials>
  </SOAP-ENV:Header>
  <SOAP-ENV:Body id='_0'>
    <DoExpressCheckoutPaymentResponse xmlns='urn:ebay:api:PayPalAPI'>
      <Timestamp xmlns='urn:ebay:apis:eBLBaseComponents'>2007-02-13T00:18:50Z</Timestamp>
      <Ack xmlns='urn:ebay:apis:eBLBaseComponents'>Success</Ack>
      <CorrelationID xmlns='urn:ebay:apis:eBLBaseComponents'>62450a4266d04</CorrelationID>
      <Version xmlns='urn:ebay:apis:eBLBaseComponents'>2.000000</Version>
      <Build xmlns='urn:ebay:apis:eBLBaseComponents'>1.0006</Build>
      <DoExpressCheckoutPaymentResponseDetails xsi:type='ebl:DoExpressCheckoutPaymentResponseDetailsType' xmlns='urn:ebay:apis:eBLBaseComponents'>
        <Token xsi:type='ebl:ExpressCheckoutTokenType'>EC-6WS104951Y388951L</Token>
        <PaymentInfo xsi:type='ebl:PaymentInfoType'>
          <TransactionID>8B266858CH956410C</TransactionID>
          <ParentTransactionID xsi:type='ebl:TransactionId'/>
          <ReceiptID/>
          <TransactionType xsi:type='ebl:PaymentTransactionCodeType'>express-checkout</TransactionType>
          <PaymentType xsi:type='ebl:PaymentCodeType'>instant</PaymentType>
          <PaymentDate xsi:type='xs:dateTime'>2007-02-13T00:18:48Z</PaymentDate>
          <GrossAmount currencyID='USD' xsi:type='cc:BasicAmountType'>3.00</GrossAmount>
          <TaxAmount currencyID='USD' xsi:type='cc:BasicAmountType'>0.00</TaxAmount>
          <ExchangeRate xsi:type='xs:string'/>
          <PaymentStatus xsi:type='ebl:PaymentStatusCodeType'>Pending</PaymentStatus>
          <PendingReason xsi:type='ebl:PendingStatusCodeType'>authorization</PendingReason>
          <ReasonCode xsi:type='ebl:ReversalReasonCodeType'>none</ReasonCode>
        </PaymentInfo>
      </DoExpressCheckoutPaymentResponseDetails>
    </DoExpressCheckoutPaymentResponse>
  </SOAP-ENV:Body>
</SOAP-ENV:Envelope>
    RESPONSE
  end

  def response_with_error
    <<-RESPONSE
<?xml version="1.0" encoding="UTF-8"?>
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:cc="urn:ebay:apis:CoreComponentTypes" xmlns:wsu="http://schemas.xmlsoap.org/ws/2002/07/utility" xmlns:saml="urn:oasis:names:tc:SAML:1.0:assertion" xmlns:ds="http://www.w3.org/2000/09/xmldsig#" xmlns:market="urn:ebay:apis:Market" xmlns:auction="urn:ebay:apis:Auction" xmlns:sizeship="urn:ebay:api:PayPalAPI/sizeship.xsd" xmlns:ship="urn:ebay:apis:ship" xmlns:skype="urn:ebay:apis:skype" xmlns:wsse="http://schemas.xmlsoap.org/ws/2002/12/secext" xmlns:ebl="urn:ebay:apis:eBLBaseComponents" xmlns:ns="urn:ebay:api:PayPalAPI">
  <SOAP-ENV:Header>
    <Security xmlns="http://schemas.xmlsoap.org/ws/2002/12/secext" xsi:type="wsse:SecurityType"/>
    <RequesterCredentials xmlns="urn:ebay:api:PayPalAPI" xsi:type="ebl:CustomSecurityHeaderType">
      <Credentials xmlns="urn:ebay:apis:eBLBaseComponents" xsi:type="ebl:UserIdPasswordType">
        <Username xsi:type="xs:string"/>
        <Password xsi:type="xs:string"/>
        <Subject xsi:type="xs:string"/>
      </Credentials>
    </RequesterCredentials>
  </SOAP-ENV:Header>
  <SOAP-ENV:Body id="_0">
    <SetExpressCheckoutResponse xmlns="urn:ebay:api:PayPalAPI">
      <Timestamp xmlns="urn:ebay:apis:eBLBaseComponents">2008-04-02T17:38:02Z</Timestamp>
      <Ack xmlns="urn:ebay:apis:eBLBaseComponents">Failure</Ack>
      <CorrelationID xmlns="urn:ebay:apis:eBLBaseComponents">cdb720feada30</CorrelationID>
      <Errors xmlns="urn:ebay:apis:eBLBaseComponents" xsi:type="ebl:ErrorType">
        <ShortMessage xsi:type="xs:string">Shipping Address Invalid City State Postal Code</ShortMessage>
        <LongMessage xsi:type="xs:string">A match of the Shipping Address City, State, and Postal Code failed.</LongMessage>
        <ErrorCode xsi:type="xs:token">10736</ErrorCode>
        <SeverityCode xmlns="urn:ebay:apis:eBLBaseComponents">Error</SeverityCode>
      </Errors>
      <Version xmlns="urn:ebay:apis:eBLBaseComponents">2.000000</Version>
      <Build xmlns="urn:ebay:apis:eBLBaseComponents">543066</Build>
    </SetExpressCheckoutResponse>
  </SOAP-ENV:Body>
</SOAP-ENV:Envelope>
    RESPONSE
  end

    def response_with_errors
      <<-RESPONSE
  <?xml version="1.0" encoding="UTF-8"?>
  <SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:cc="urn:ebay:apis:CoreComponentTypes" xmlns:wsu="http://schemas.xmlsoap.org/ws/2002/07/utility" xmlns:saml="urn:oasis:names:tc:SAML:1.0:assertion" xmlns:ds="http://www.w3.org/2000/09/xmldsig#" xmlns:market="urn:ebay:apis:Market" xmlns:auction="urn:ebay:apis:Auction" xmlns:sizeship="urn:ebay:api:PayPalAPI/sizeship.xsd" xmlns:ship="urn:ebay:apis:ship" xmlns:skype="urn:ebay:apis:skype" xmlns:wsse="http://schemas.xmlsoap.org/ws/2002/12/secext" xmlns:ebl="urn:ebay:apis:eBLBaseComponents" xmlns:ns="urn:ebay:api:PayPalAPI">
    <SOAP-ENV:Header>
      <Security xmlns="http://schemas.xmlsoap.org/ws/2002/12/secext" xsi:type="wsse:SecurityType"/>
      <RequesterCredentials xmlns="urn:ebay:api:PayPalAPI" xsi:type="ebl:CustomSecurityHeaderType">
        <Credentials xmlns="urn:ebay:apis:eBLBaseComponents" xsi:type="ebl:UserIdPasswordType">
          <Username xsi:type="xs:string"/>
          <Password xsi:type="xs:string"/>
          <Subject xsi:type="xs:string"/>
        </Credentials>
      </RequesterCredentials>
    </SOAP-ENV:Header>
    <SOAP-ENV:Body id="_0">
      <SetExpressCheckoutResponse xmlns="urn:ebay:api:PayPalAPI">
        <Timestamp xmlns="urn:ebay:apis:eBLBaseComponents">2008-04-02T17:38:02Z</Timestamp>
        <Ack xmlns="urn:ebay:apis:eBLBaseComponents">Failure</Ack>
        <CorrelationID xmlns="urn:ebay:apis:eBLBaseComponents">cdb720feada30</CorrelationID>
        <Errors xmlns="urn:ebay:apis:eBLBaseComponents" xsi:type="ebl:ErrorType">
          <ShortMessage xsi:type="xs:string">Shipping Address Invalid City State Postal Code</ShortMessage>
          <LongMessage xsi:type="xs:string">A match of the Shipping Address City, State, and Postal Code failed.</LongMessage>
          <ErrorCode xsi:type="xs:token">10736</ErrorCode>
          <SeverityCode xmlns="urn:ebay:apis:eBLBaseComponents">Error</SeverityCode>
        </Errors>
        <Errors xmlns="urn:ebay:apis:eBLBaseComponents" xsi:type="ebl:ErrorType">
           <ShortMessage xsi:type="xs:string">Authentication/Authorization Failed</ShortMessage>
          <LongMessage xsi:type="xs:string">You do not have permissions to make this API call</LongMessage>
          <ErrorCode xsi:type="xs:token">10002</ErrorCode>
          <SeverityCode xmlns="urn:ebay:apis:eBLBaseComponents">Error</SeverityCode>
        </Errors>
        <Version xmlns="urn:ebay:apis:eBLBaseComponents">2.000000</Version>
        <Build xmlns="urn:ebay:apis:eBLBaseComponents">543066</Build>
      </SetExpressCheckoutResponse>
    </SOAP-ENV:Body>
  </SOAP-ENV:Envelope>
      RESPONSE
    end

    def response_with_duplicate_errors
      <<-RESPONSE
  <?xml version="1.0" encoding="UTF-8"?>
  <SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:cc="urn:ebay:apis:CoreComponentTypes" xmlns:wsu="http://schemas.xmlsoap.org/ws/2002/07/utility" xmlns:saml="urn:oasis:names:tc:SAML:1.0:assertion" xmlns:ds="http://www.w3.org/2000/09/xmldsig#" xmlns:market="urn:ebay:apis:Market" xmlns:auction="urn:ebay:apis:Auction" xmlns:sizeship="urn:ebay:api:PayPalAPI/sizeship.xsd" xmlns:ship="urn:ebay:apis:ship" xmlns:skype="urn:ebay:apis:skype" xmlns:wsse="http://schemas.xmlsoap.org/ws/2002/12/secext" xmlns:ebl="urn:ebay:apis:eBLBaseComponents" xmlns:ns="urn:ebay:api:PayPalAPI">
    <SOAP-ENV:Header>
      <Security xmlns="http://schemas.xmlsoap.org/ws/2002/12/secext" xsi:type="wsse:SecurityType"/>
      <RequesterCredentials xmlns="urn:ebay:api:PayPalAPI" xsi:type="ebl:CustomSecurityHeaderType">
        <Credentials xmlns="urn:ebay:apis:eBLBaseComponents" xsi:type="ebl:UserIdPasswordType">
          <Username xsi:type="xs:string"/>
          <Password xsi:type="xs:string"/>
          <Subject xsi:type="xs:string"/>
        </Credentials>
      </RequesterCredentials>
    </SOAP-ENV:Header>
    <SOAP-ENV:Body id="_0">
      <SetExpressCheckoutResponse xmlns="urn:ebay:api:PayPalAPI">
        <Timestamp xmlns="urn:ebay:apis:eBLBaseComponents">2008-04-02T17:38:02Z</Timestamp>
        <Ack xmlns="urn:ebay:apis:eBLBaseComponents">Failure</Ack>
        <CorrelationID xmlns="urn:ebay:apis:eBLBaseComponents">cdb720feada30</CorrelationID>
        <Errors xmlns="urn:ebay:apis:eBLBaseComponents" xsi:type="ebl:ErrorType">
          <ShortMessage xsi:type="xs:string">Shipping Address Invalid City State Postal Code</ShortMessage>
          <LongMessage xsi:type="xs:string">A match of the Shipping Address City, State, and Postal Code failed.</LongMessage>
          <ErrorCode xsi:type="xs:token">10736</ErrorCode>
          <SeverityCode xmlns="urn:ebay:apis:eBLBaseComponents">Error</SeverityCode>
        </Errors>
         <Errors xmlns="urn:ebay:apis:eBLBaseComponents" xsi:type="ebl:ErrorType">
            <ShortMessage xsi:type="xs:string">Shipping Address Invalid City State Postal Code</ShortMessage>
            <LongMessage xsi:type="xs:string">A match of the Shipping Address City, State, and Postal Code failed.</LongMessage>
            <ErrorCode xsi:type="xs:token">10736</ErrorCode>
            <SeverityCode xmlns="urn:ebay:apis:eBLBaseComponents">Error</SeverityCode>
        </Errors>
        <Version xmlns="urn:ebay:apis:eBLBaseComponents">2.000000</Version>
        <Build xmlns="urn:ebay:apis:eBLBaseComponents">543066</Build>
      </SetExpressCheckoutResponse>
    </SOAP-ENV:Body>
  </SOAP-ENV:Envelope>
      RESPONSE
    end

    def successful_cancel_billing_agreement_response
      <<-RESPONSE
        <?xml version="1.0" encoding="UTF-8"?><SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/"
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:cc="urn:ebay:apis:CoreComponentTypes"
        xmlns:wsu="http://schemas.xmlsoap.org/ws/2002/07/utility" xmlns:saml="urn:oasis:names:tc:SAML:1.0:assertion" xmlns:ds="http://www.w3.org/2000/09/xmldsig#"
        xmlns:wsse="http://schemas.xmlsoap.org/ws/2002/12/secext" xmlns:ed="urn:ebay:apis:EnhancedDataTypes" xmlns:ebl="urn:ebay:apis:eBLBaseComponents"
        xmlns:ns="urn:ebay:api:PayPalAPI"><SOAP-ENV:Header><Security xmlns="http://schemas.xmlsoap.org/ws/2002/12/secext" xsi:type="wsse:SecurityType"></Security><RequesterCredentials
        xmlns="urn:ebay:api:PayPalAPI" xsi:type="ebl:CustomSecurityHeaderType"><Credentials xmlns="urn:ebay:apis:eBLBaseComponents" xsi:type="ebl:UserIdPasswordType"><Username
        xsi:type="xs:string"></Username><Password xsi:type="xs:string"></Password><Signature xsi:type="xs:string"></Signature><Subject
        xsi:type="xs:string"></Subject></Credentials></RequesterCredentials></SOAP-ENV:Header><SOAP-ENV:Body id="_0"><BAUpdateResponse xmlns="urn:ebay:api:PayPalAPI"><Timestamp
        xmlns="urn:ebay:apis:eBLBaseComponents">2013-06-04T16:24:31Z</Timestamp><Ack xmlns="urn:ebay:apis:eBLBaseComponents">Success</Ack><CorrelationID
        xmlns="urn:ebay:apis:eBLBaseComponents">aecbb96bd4658</CorrelationID><Version xmlns="urn:ebay:apis:eBLBaseComponents">72</Version><Build
        xmlns="urn:ebay:apis:eBLBaseComponents">6118442</Build><BAUpdateResponseDetails xmlns="urn:ebay:apis:eBLBaseComponents" xsi:type="ebl:BAUpdateResponseDetailsType"><BillingAgreementID
        xsi:type="xs:string">B-3RU433629T663020S</BillingAgreementID><BillingAgreementDescription xsi:type="xs:string">Wow. Amazing.</BillingAgreementDescription><BillingAgreementStatus
        xsi:type="ebl:MerchantPullStatusCodeType">Canceled</BillingAgreementStatus><PayerInfo xsi:type="ebl:PayerInfoType"><Payer xsi:type="ebl:EmailAddressType">duff@example.com</Payer><PayerID
        xsi:type="ebl:UserIDType">VZNKJ2ZWMYK2E</PayerID><PayerStatus xsi:type="ebl:PayPalUserStatusCodeType">verified</PayerStatus><PayerName xsi:type="ebl:PersonNameType"><Salutation
        xmlns="urn:ebay:apis:eBLBaseComponents"></Salutation><FirstName xmlns="urn:ebay:apis:eBLBaseComponents">Duff</FirstName><MiddleName
        xmlns="urn:ebay:apis:eBLBaseComponents"></MiddleName><LastName xmlns="urn:ebay:apis:eBLBaseComponents">Jones</LastName><Suffix
        xmlns="urn:ebay:apis:eBLBaseComponents"></Suffix></PayerName><PayerCountry xsi:type="ebl:CountryCodeType">US</PayerCountry><PayerBusiness xsi:type="xs:string"></PayerBusiness><Address
        xsi:type="ebl:AddressType"><Name xsi:type="xs:string"></Name><Street1 xsi:type="xs:string"></Street1><Street2 xsi:type="xs:string"></Street2><CityName
        xsi:type="xs:string"></CityName><StateOrProvince xsi:type="xs:string"></StateOrProvince><CountryName></CountryName><Phone xsi:type="xs:string"></Phone><PostalCode
        xsi:type="xs:string"></PostalCode><AddressID xsi:type="xs:string"></AddressID><AddressOwner xsi:type="ebl:AddressOwnerCodeType">PayPal</AddressOwner><ExternalAddressID
        xsi:type="xs:string"></ExternalAddressID><AddressStatus
        xsi:type="ebl:AddressStatusCodeType">None</AddressStatus></Address></PayerInfo></BAUpdateResponseDetails></BAUpdateResponse></SOAP-ENV:Body></SOAP-ENV:Envelope>
      RESPONSE
    end

    def failed_cancel_billing_agreement_response
      <<-RESPONSE
        <?xml version="1.0" encoding="UTF-8"?><SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/"
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:cc="urn:ebay:apis:CoreComponentTypes"
        xmlns:wsu="http://schemas.xmlsoap.org/ws/2002/07/utility" xmlns:saml="urn:oasis:names:tc:SAML:1.0:assertion" xmlns:ds="http://www.w3.org/2000/09/xmldsig#"
        xmlns:wsse="http://schemas.xmlsoap.org/ws/2002/12/secext" xmlns:ed="urn:ebay:apis:EnhancedDataTypes" xmlns:ebl="urn:ebay:apis:eBLBaseComponents"
        xmlns:ns="urn:ebay:api:PayPalAPI"><SOAP-ENV:Header><Security xmlns="http://schemas.xmlsoap.org/ws/2002/12/secext" xsi:type="wsse:SecurityType"></Security><RequesterCredentials
        xmlns="urn:ebay:api:PayPalAPI" xsi:type="ebl:CustomSecurityHeaderType"><Credentials xmlns="urn:ebay:apis:eBLBaseComponents" xsi:type="ebl:UserIdPasswordType"><Username
        xsi:type="xs:string"></Username><Password xsi:type="xs:string"></Password><Signature xsi:type="xs:string"></Signature><Subject
        xsi:type="xs:string"></Subject></Credentials></RequesterCredentials></SOAP-ENV:Header><SOAP-ENV:Body id="_0"><BAUpdateResponse xmlns="urn:ebay:api:PayPalAPI"><Timestamp
        xmlns="urn:ebay:apis:eBLBaseComponents">2013-06-04T16:25:06Z</Timestamp><Ack xmlns="urn:ebay:apis:eBLBaseComponents">Failure</Ack><CorrelationID
        xmlns="urn:ebay:apis:eBLBaseComponents">5ec2d55830b40</CorrelationID><Errors xmlns="urn:ebay:apis:eBLBaseComponents" xsi:type="ebl:ErrorType"><ShortMessage xsi:type="xs:string">Billing
        Agreement was cancelled</ShortMessage><LongMessage xsi:type="xs:string">Billing Agreement was cancelled</LongMessage><ErrorCode xsi:type="xs:token">10201</ErrorCode><SeverityCode
        xmlns="urn:ebay:apis:eBLBaseComponents">Error</SeverityCode></Errors><Version xmlns="urn:ebay:apis:eBLBaseComponents">72</Version><Build
        xmlns="urn:ebay:apis:eBLBaseComponents">6118442</Build><BAUpdateResponseDetails xmlns="urn:ebay:apis:eBLBaseComponents" xsi:type="ebl:BAUpdateResponseDetailsType"><PayerInfo
        xsi:type="ebl:PayerInfoType"><Payer xsi:type="ebl:EmailAddressType"></Payer><PayerID xsi:type="ebl:UserIDType"></PayerID><PayerStatus
        xsi:type="ebl:PayPalUserStatusCodeType">unverified</PayerStatus><PayerName xsi:type="ebl:PersonNameType"><Salutation xmlns="urn:ebay:apis:eBLBaseComponents"></Salutation><FirstName
        xmlns="urn:ebay:apis:eBLBaseComponents"></FirstName><MiddleName xmlns="urn:ebay:apis:eBLBaseComponents"></MiddleName><LastName xmlns="urn:ebay:apis:eBLBaseComponents"></LastName><Suffix
        xmlns="urn:ebay:apis:eBLBaseComponents"></Suffix></PayerName><PayerBusiness xsi:type="xs:string"></PayerBusiness><Address xsi:type="ebl:AddressType"><Name
        xsi:type="xs:string"></Name><Street1 xsi:type="xs:string"></Street1><Street2 xsi:type="xs:string"></Street2><CityName xsi:type="xs:string"></CityName><StateOrProvince
        xsi:type="xs:string"></StateOrProvince><CountryName></CountryName><Phone xsi:type="xs:string"></Phone><PostalCode xsi:type="xs:string"></PostalCode><AddressID
        xsi:type="xs:string"></AddressID><AddressOwner xsi:type="ebl:AddressOwnerCodeType">PayPal</AddressOwner><ExternalAddressID xsi:type="xs:string"></ExternalAddressID><AddressStatus
        xsi:type="ebl:AddressStatusCodeType">None</AddressStatus></Address></PayerInfo></BAUpdateResponseDetails></BAUpdateResponse></SOAP-ENV:Body></SOAP-ENV:Envelope>
      RESPONSE
    end

    def successful_billing_agreement_details_response
      <<-RESPONSE
        <?xml version="1.0" encoding="UTF-8"?><SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/"
        xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:cc="urn:ebay:apis:CoreComponentTypes"
        xmlns:wsu="http://schemas.xmlsoap.org/ws/2002/07/utility" xmlns:saml="urn:oasis:names:tc:SAML:1.0:assertion"
        xmlns:ds="http://www.w3.org/2000/09/xmldsig#" xmlns:wsse="http://schemas.xmlsoap.org/ws/2002/12/secext" xmlns:ed="urn:ebay:apis:EnhancedDataTypes"
        xmlns:ebl="urn:ebay:apis:eBLBaseComponents" xmlns:ns="urn:ebay:api:PayPalAPI"><SOAP-ENV:Header><Security
        xmlns="http://schemas.xmlsoap.org/ws/2002/12/secext" xsi:type="wsse:SecurityType"></Security><RequesterCredentials
        xmlns="urn:ebay:api:PayPalAPI" xsi:type="ebl:CustomSecurityHeaderType"><Credentials xmlns="urn:ebay:apis:eBLBaseComponents"
        xsi:type="ebl:UserIdPasswordType"><Username xsi:type="xs:string"></Username><Password xsi:type="xs:string"></Password><Signature
        xsi:type="xs:string"></Signature><Subject xsi:type="xs:string"></Subject></Credentials></RequesterCredentials></SOAP-ENV:Header><SOAP-ENV:Body id="_0">
        <BAUpdateResponse xmlns="urn:ebay:api:PayPalAPI"><Timestamp xmlns="urn:ebay:apis:eBLBaseComponents">2014-05-08T09:22:03Z</Timestamp>
        <Ack xmlns="urn:ebay:apis:eBLBaseComponents">Success</Ack><CorrelationID xmlns="urn:ebay:apis:eBLBaseComponents">f84ed24f5bd6d</CorrelationID>
        <Version xmlns="urn:ebay:apis:eBLBaseComponents">72</Version><Build xmlns="urn:ebay:apis:eBLBaseComponents">10918103</Build><BAUpdateResponseDetails
        xmlns="urn:ebay:apis:eBLBaseComponents" xsi:type="ebl:BAUpdateResponseDetailsType">
        <BillingAgreementID xsi:type="xs:string">B-6VE21702A47915521</BillingAgreementID><BillingAgreementDescription
        xsi:type="xs:string">My active merchant custom description</BillingAgreementDescription>
        <BillingAgreementStatus xsi:type="ebl:MerchantPullStatusCodeType">Active</BillingAgreementStatus><PayerInfo xsi:type="ebl:PayerInfoType"><Payer
        xsi:type="ebl:EmailAddressType">ivan.rostovsky.xan@gmail.com</Payer><PayerID xsi:type="ebl:UserIDType">SW3AR2WYZ3NJW</PayerID><PayerStatus
        xsi:type="ebl:PayPalUserStatusCodeType">verified</PayerStatus><PayerName xsi:type="ebl:PersonNameType"><Salutation
        xmlns="urn:ebay:apis:eBLBaseComponents"></Salutation><FirstName xmlns="urn:ebay:apis:eBLBaseComponents">Ivan</FirstName><MiddleName
        xmlns="urn:ebay:apis:eBLBaseComponents"></MiddleName><LastName xmlns="urn:ebay:apis:eBLBaseComponents">Rostovsky</LastName>
        <Suffix xmlns="urn:ebay:apis:eBLBaseComponents"></Suffix></PayerName><PayerCountry xsi:type="ebl:CountryCodeType">US</PayerCountry>
        <PayerBusiness xsi:type="xs:string"></PayerBusiness><Address xsi:type="ebl:AddressType"><Name xsi:type="xs:string"></Name><Street1
        xsi:type="xs:string"></Street1><Street2 xsi:type="xs:string"></Street2><CityName xsi:type="xs:string"></CityName><StateOrProvince
        xsi:type="xs:string"></StateOrProvince><CountryName></CountryName><Phone xsi:type="xs:string"></Phone><PostalCode xsi:type="xs:string">
        </PostalCode><AddressID xsi:type="xs:string"></AddressID><AddressOwner xsi:type="ebl:AddressOwnerCodeType">PayPal</AddressOwner>
        <ExternalAddressID xsi:type="xs:string"></ExternalAddressID><AddressStatus xsi:type="ebl:AddressStatusCodeType">None</AddressStatus>
        </Address></PayerInfo></BAUpdateResponseDetails></BAUpdateResponse></SOAP-ENV:Body></SOAP-ENV:Envelope>
      RESPONSE
    end

    def failure_billing_agreement_details_response
      <<-RESPONSE
      <?xml version="1.0" encoding="UTF-8"?><SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/"
      xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
      xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:cc="urn:ebay:apis:CoreComponentTypes"
      xmlns:wsu="http://schemas.xmlsoap.org/ws/2002/07/utility" xmlns:saml="urn:oasis:names:tc:SAML:1.0:assertion"
      xmlns:ds="http://www.w3.org/2000/09/xmldsig#" xmlns:wsse="http://schemas.xmlsoap.org/ws/2002/12/secext"
      xmlns:ed="urn:ebay:apis:EnhancedDataTypes" xmlns:ebl="urn:ebay:apis:eBLBaseComponents"
      xmlns:ns="urn:ebay:api:PayPalAPI"><SOAP-ENV:Header><Security xmlns="http://schemas.xmlsoap.org/ws/2002/12/secext"
      xsi:type="wsse:SecurityType"></Security><RequesterCredentials xmlns="urn:ebay:api:PayPalAPI" xsi:type="ebl:CustomSecurityHeaderType"><Credentials
      xmlns="urn:ebay:apis:eBLBaseComponents" xsi:type="ebl:UserIdPasswordType"><Username xsi:type="xs:string"></Username><Password
      xsi:type="xs:string"></Password><Signature xsi:type="xs:string"></Signature><Subject xsi:type="xs:string"></Subject></Credentials>
      </RequesterCredentials></SOAP-ENV:Header><SOAP-ENV:Body id="_0"><BAUpdateResponse xmlns="urn:ebay:api:PayPalAPI"><Timestamp
      xmlns="urn:ebay:apis:eBLBaseComponents">2014-05-08T09:30:49Z</Timestamp><Ack xmlns="urn:ebay:apis:eBLBaseComponents">Failure</Ack>
      <CorrelationID xmlns="urn:ebay:apis:eBLBaseComponents">fb481ac974e22</CorrelationID><Errors xmlns="urn:ebay:apis:eBLBaseComponents"
      xsi:type="ebl:ErrorType"><ShortMessage xsi:type="xs:string">Billing Agreement Id or transaction Id is not valid</ShortMessage>
      <LongMessage xsi:type="xs:string">Billing Agreement Id or transaction Id is not valid</LongMessage><ErrorCode xsi:type="xs:token">11451</ErrorCode>
      <SeverityCode xmlns="urn:ebay:apis:eBLBaseComponents">Error</SeverityCode></Errors><Version xmlns="urn:ebay:apis:eBLBaseComponents">72</Version>
      <Build xmlns="urn:ebay:apis:eBLBaseComponents">10918103</Build><BAUpdateResponseDetails xmlns="urn:ebay:apis:eBLBaseComponents"
      xsi:type="ebl:BAUpdateResponseDetailsType"><PayerInfo xsi:type="ebl:PayerInfoType"><Payer xsi:type="ebl:EmailAddressType"></Payer>
      <PayerID xsi:type="ebl:UserIDType"></PayerID><PayerStatus xsi:type="ebl:PayPalUserStatusCodeType">unverified</PayerStatus><PayerName
      xsi:type="ebl:PersonNameType"><Salutation xmlns="urn:ebay:apis:eBLBaseComponents"></Salutation><FirstName xmlns="urn:ebay:apis:eBLBaseComponents">
      </FirstName><MiddleName xmlns="urn:ebay:apis:eBLBaseComponents"></MiddleName><LastName xmlns="urn:ebay:apis:eBLBaseComponents"></LastName><Suffix
      xmlns="urn:ebay:apis:eBLBaseComponents"></Suffix></PayerName><PayerBusiness xsi:type="xs:string"></PayerBusiness><Address xsi:type="ebl:AddressType">
      <Name xsi:type="xs:string"></Name><Street1 xsi:type="xs:string"></Street1><Street2 xsi:type="xs:string"></Street2><CityName xsi:type="xs:string">
      </CityName><StateOrProvince xsi:type="xs:string"></StateOrProvince><CountryName></CountryName><Phone xsi:type="xs:string"></Phone><PostalCode
      xsi:type="xs:string"></PostalCode><AddressID xsi:type="xs:string"></AddressID><AddressOwner xsi:type="ebl:AddressOwnerCodeType">PayPal</AddressOwner>
      <ExternalAddressID xsi:type="xs:string"></ExternalAddressID><AddressStatus xsi:type="ebl:AddressStatusCodeType">None</AddressStatus></Address>
      </PayerInfo></BAUpdateResponseDetails></BAUpdateResponse></SOAP-ENV:Body></SOAP-ENV:Envelope>
      RESPONSE
    end
end
