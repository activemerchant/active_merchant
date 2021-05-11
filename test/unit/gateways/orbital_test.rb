# encoding: utf-8

require 'test_helper'
require 'nokogiri'

class OrbitalGatewayTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = ActiveMerchant::Billing::OrbitalGateway.new(
      login: 'login',
      password: 'password',
      merchant_id: 'merchant_id'
    )
    @customer_ref_num = 'ABC'
    # Electronic Check object with test credentials of saving account
    @echeck = check(account_number: '072403004', account_type: 'savings', routing_number: '072403004')

    @level2 = {
      tax_indicator: '1',
      tax: '10',
      advice_addendum_1: 'taa1 - test',
      advice_addendum_2: 'taa2 - test',
      advice_addendum_3: 'taa3 - test',
      advice_addendum_4: 'taa4 - test',
      purchase_order: '123abc',
      name: address[:name],
      address1: address[:address1],
      address2: address[:address2],
      city: address[:city],
      state: address[:state],
      zip: address[:zip]
    }

    @level3 = {
      freight_amount: '15',
      duty_amount: '10',
      dest_country: 'US',
      ship_from_zip: '12345',
      discount_amount: '20',
      vat_tax: '25',
      alt_tax: '30',
      vat_rate: '7',
      alt_ind: 'Y'
    }

    @line_items =
      [
        {
          desc: 'credit card payment',
          prod_cd: 'service',
          qty: '30',
          u_o_m: 'EAC',
          tax_amt: '10',
          tax_rate: '8.25',
          line_tot: '20',
          disc: '6',
          unit_cost: '5',
          gross_net: 'Y',
          disc_ind: 'Y'
        },
        {
          desc: 'credit card payment',
          prod_cd: 'service',
          qty: '30',
          u_o_m: 'EAC',
          tax_amt: '10',
          tax_rate: '8.25',
          line_tot: '20',
          disc: '6',
          unit_cost: '5',
          gross_net: 'Y',
          disc_ind: 'Y'
        }
      ]

    @options = {
      order_id: '1',
      card_indicators: 'y'
    }

    @options_stored_credentials = {
      mit_msg_type: 'MRSB',
      mit_stored_credential_ind: 'Y',
      mit_submitted_transaction_id: '123456abcdef'
    }
    @normalized_mit_stored_credential = {
      stored_credential: {
        initial_transaction: false,
        initiator: 'merchant',
        reason_type: 'unscheduled',
        network_transaction_id: 'abcdefg12345678'
      }
    }
    @three_d_secure_options = {
      three_d_secure: {
        eci: '5',
        xid: 'TESTXID',
        cavv: 'TESTCAVV',
        version: '2',
        ds_transaction_id: '97267598FAE648F28083C23433990FBC'
      }
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.purchase(50, credit_card, order_id: '1')
    assert_instance_of Response, response
    assert_success response
    assert_equal '4A5398CF9B87744GG84A1D30F2F2321C66249416;1', response.authorization
  end

  def test_successful_purchase_with_echeck
    @gateway.expects(:ssl_post).returns(successful_purchase_with_echeck_response)

    assert response = @gateway.purchase(50, @echeck, order_id: '9baedc697f2cf06457de78')
    assert_instance_of Response, response
    assert_equal 'Approved', response.message
    assert_success response
    assert_equal '5F8E8BEE7299FD339A38F70CFF6E5D010EF55498;9baedc697f2cf06457de78', response.authorization
  end

  def test_failed_purchase_with_echeck
    @gateway.expects(:ssl_post).returns(failed_echeck_for_invalid_routing_response)

    assert response = @gateway.purchase(50, @echeck, order_id: '9baedc697f2cf06457de78')
    assert_instance_of Response, response
    assert_failure response
    assert_equal 'Invalid ECP Account Route: []. The field is missing, invalid, or it has exceeded the max length of: [9].', response.message
    assert_equal '888', response.params['proc_status']
  end

  def test_successful_force_capture_with_echeck
    @gateway.expects(:ssl_post).returns(successful_force_capture_with_echeck_response)

    assert response = @gateway.purchase(31, @echeck, order_id: '2', force_capture: true)
    assert_instance_of Response, response
    assert_match 'APPROVAL', response.message
    assert_equal 'Approved and Completed', response.params['status_msg']
    assert_equal '5F8ED3D950A43BD63369845D5385B6354C3654B4;2930847bc732eb4e8102cf', response.authorization
  end

  def test_successful_force_capture_with_echeck_prenote
    @gateway.expects(:ssl_post).returns(successful_force_capture_with_echeck_prenote_response)

    assert response = @gateway.authorize(0, @echeck, order_id: '2', force_capture: true, action_code: 'W9')
    assert_instance_of Response, response
    assert_match 'APPROVAL', response.message
    assert_equal 'Approved and Completed', response.params['status_msg']
    assert_equal '5F8ED3D950A43BD63369845D5385B6354C3654B4;2930847bc732eb4e8102cf', response.authorization
  end

  def test_failed_force_capture_with_echeck_prenote
    @gateway.expects(:ssl_post).returns(failed_force_capture_with_echeck_prenote_response)

    assert response = @gateway.authorize(0, @echeck, order_id: '2', force_capture: true, action_code: 'W7')
    assert_instance_of Response, response
    assert_failure response
    assert_equal ' EWS: Invalid Action Code [W7], For Transaction Type [A].', response.message
  end

  def test_level2_data
    stub_comms do
      @gateway.purchase(50, credit_card, @options.merge(level_2_data: @level2))
    end.check_request do |_endpoint, data, _headers|
      assert_match %{<TaxInd>#{@level2[:tax_indicator].to_i}</TaxInd>}, data
      assert_match %{<Tax>#{@level2[:tax].to_i}</Tax>}, data
      assert_match %{<AMEXTranAdvAddn1>#{@level2[:advice_addendum_1]}</AMEXTranAdvAddn1>}, data
      assert_match %{<AMEXTranAdvAddn2>#{@level2[:advice_addendum_2]}</AMEXTranAdvAddn2>}, data
      assert_match %{<AMEXTranAdvAddn3>#{@level2[:advice_addendum_3]}</AMEXTranAdvAddn3>}, data
      assert_match %{<AMEXTranAdvAddn4>#{@level2[:advice_addendum_4]}</AMEXTranAdvAddn4>}, data
      assert_match %{<PCOrderNum>#{@level2[:purchase_order]}</PCOrderNum>}, data
      assert_match %{<PCDestZip>#{@level2[:zip]}</PCDestZip>}, data
      assert_match %{<PCDestName>#{@level2[:name]}</PCDestName>}, data
      assert_match %{<PCDestAddress1>#{@level2[:address1]}</PCDestAddress1>}, data
      assert_match %{<PCDestAddress2>#{@level2[:address2]}</PCDestAddress2>}, data
      assert_match %{<PCDestCity>#{@level2[:city]}</PCDestCity>}, data
      assert_match %{<PCDestState>#{@level2[:state]}</PCDestState>}, data
    end.respond_with(successful_purchase_response)
  end

  def test_level3_data
    stub_comms do
      @gateway.purchase(50, credit_card, @options.merge(level_3_data: @level3))
    end.check_request do |_endpoint, data, _headers|
      assert_match %{<PC3FreightAmt>#{@level3[:freight_amount].to_i}</PC3FreightAmt>}, data
      assert_match %{<PC3DutyAmt>#{@level3[:duty_amount].to_i}</PC3DutyAmt>}, data
      assert_match %{<PC3DestCountryCd>#{@level3[:dest_country]}</PC3DestCountryCd>}, data
      assert_match %{<PC3ShipFromZip>#{@level3[:ship_from_zip].to_i}</PC3ShipFromZip>}, data
      assert_match %{<PC3DiscAmt>#{@level3[:discount_amount].to_i}</PC3DiscAmt>}, data
      assert_match %{<PC3VATtaxAmt>#{@level3[:vat_tax].to_i}</PC3VATtaxAmt>}, data
      assert_match %{<PC3VATtaxRate>#{@level3[:vat_rate].to_i}</PC3VATtaxRate>}, data
      assert_match %{<PC3AltTaxAmt>#{@level3[:alt_tax].to_i}</PC3AltTaxAmt>}, data
      assert_match %{<PC3AltTaxInd>#{@level3[:alt_ind]}</PC3AltTaxInd>}, data
    end.respond_with(successful_purchase_response)
  end

  def test_line_items_data
    stub_comms do
      @gateway.purchase(50, credit_card, @options.merge(line_items: @line_items))
    end.check_request do |_endpoint, data, _headers|
      assert_match %{<PC3DtlIndex>1</PC3DtlIndex>}, data
      assert_match %{<PC3DtlDesc>#{@line_items[1][:desc]}</PC3DtlDesc>}, data
      assert_match %{<PC3DtlProdCd>#{@line_items[1][:prod_cd]}</PC3DtlProdCd>}, data
      assert_match %{<PC3DtlQty>#{@line_items[1][:qty].to_i}</PC3DtlQty>}, data
      assert_match %{<PC3DtlUOM>#{@line_items[1][:u_o_m]}</PC3DtlUOM>}, data
      assert_match %{<PC3DtlTaxAmt>#{@line_items[1][:tax_amt].to_i}</PC3DtlTaxAmt>}, data
      assert_match %{<PC3DtlTaxRate>#{@line_items[1][:tax_rate]}</PC3DtlTaxRate>}, data
      assert_match %{<PC3Dtllinetot>#{@line_items[1][:line_tot].to_i}</PC3Dtllinetot>}, data
      assert_match %{<PC3DtlDisc>#{@line_items[1][:disc].to_i}</PC3DtlDisc>}, data
      assert_match %{<PC3DtlUnitCost>#{@line_items[1][:unit_cost].to_i}</PC3DtlUnitCost>}, data
      assert_match %{<PC3DtlGrossNet>#{@line_items[1][:gross_net]}</PC3DtlGrossNet>}, data
      assert_match %{<PC3DtlDiscInd>#{@line_items[1][:disc_ind]}</PC3DtlDiscInd>}, data
      assert_match %{<PC3DtlIndex>2</PC3DtlIndex>}, data
    end.respond_with(successful_purchase_response)
  end

  def test_network_tokenization_credit_card_data
    stub_comms do
      @gateway.purchase(50, network_tokenization_credit_card(nil, eci: '5', transaction_id: 'BwABB4JRdgAAAAAAiFF2AAAAAAA='), @options)
    end.check_request do |_endpoint, data, _headers|
      assert_match %{<AuthenticationECIInd>5</AuthenticationECIInd>}, data
      assert_match %{<DPANInd>Y</DPANInd>}, data
      assert_match %{DigitalTokenCryptogram}, data
    end.respond_with(successful_purchase_response)
  end

  def test_schema_for_soft_descriptors_with_network_tokenization_credit_card_data
    options = @options.merge(
      soft_descriptors: {
        merchant_name: 'Merch',
        product_description: 'Description',
        merchant_email: 'email@example'
      }
    )
    stub_comms do
      @gateway.purchase(50, network_tokenization_credit_card(nil, eci: '5', transaction_id: 'BwABB4JRdgAAAAAAiFF2AAAAAAA='), options)
    end.check_request do |_endpoint, data, _headers|
      # Soft descriptor fields should come before dpan and cryptogram fields
      assert_match %{<SDMerchantEmail>email@example<\/SDMerchantEmail><DPANInd>Y<\/DPANInd><DigitalTokenCryptogram}, data.gsub(/\s+/, '')
    end.respond_with(successful_purchase_response)
  end

  def test_three_d_secure_data_on_visa_purchase
    stub_comms do
      @gateway.purchase(50, credit_card, @options.merge(@three_d_secure_options))
    end.check_request do |_endpoint, data, _headers|
      assert_match %{<AuthenticationECIInd>5</AuthenticationECIInd>}, data
      assert_match %{<CAVV>TESTCAVV</CAVV>}, data
      assert_match %{<XID>TESTXID</XID>}, data
    end.respond_with(successful_purchase_response)
  end

  def test_three_d_secure_data_on_visa_authorization
    stub_comms do
      @gateway.authorize(50, credit_card, @options.merge(@three_d_secure_options))
    end.check_request do |_endpoint, data, _headers|
      assert_match %{<AuthenticationECIInd>5</AuthenticationECIInd>}, data
      assert_match %{<CAVV>TESTCAVV</CAVV>}, data
      assert_match %{<XID>TESTXID</XID>}, data
    end.respond_with(successful_purchase_response)
  end

  def test_three_d_secure_data_on_master_purchase
    stub_comms do
      @gateway.purchase(50, credit_card(nil, brand: 'master'), @options.merge(@three_d_secure_options))
    end.check_request do |_endpoint, data, _headers|
      assert_match %{<AuthenticationECIInd>5</AuthenticationECIInd>}, data
      assert_match %{<AAV>TESTCAVV</AAV>}, data
      assert_match %{<MCProgramProtocol>2</MCProgramProtocol>}, data
      assert_match %{<MCDirectoryTransID>97267598FAE648F28083C23433990FBC</MCDirectoryTransID>}, data
      assert_match %{<UCAFInd>4</UCAFInd>}, data
    end.respond_with(successful_purchase_response)
  end

  def test_three_d_secure_data_on_master_authorization
    stub_comms do
      @gateway.authorize(50, credit_card(nil, brand: 'master'), @options.merge(@three_d_secure_options))
    end.check_request do |_endpoint, data, _headers|
      assert_match %{<AuthenticationECIInd>5</AuthenticationECIInd>}, data
      assert_match %{<AAV>TESTCAVV</AAV>}, data
      assert_match %{<MCProgramProtocol>2</MCProgramProtocol>}, data
      assert_match %{<MCDirectoryTransID>97267598FAE648F28083C23433990FBC</MCDirectoryTransID>}, data
      assert_match %{<UCAFInd>4</UCAFInd>}, data
    end.respond_with(successful_purchase_response)
  end

  def test_three_d_secure_data_on_master_sca_recurring
    options_local = {
      three_d_secure: {
        eci: '7',
        xid: 'TESTXID',
        cavv: 'AAAEEEDDDSSSAAA2243234',
        ds_transaction_id: '97267598FAE648F28083C23433990FBC',
        version: 2
      },
      sca_recurring: 'Y'
    }

    stub_comms do
      @gateway.authorize(50, credit_card(nil, brand: 'master'), @options.merge(options_local))
    end.check_request do |_endpoint, data, _headers|
      assert_match %{<AuthenticationECIInd>7</AuthenticationECIInd>}, data
      assert_match %{<AAV>AAAEEEDDDSSSAAA2243234</AAV>}, data
      assert_match %{<MCProgramProtocol>2</MCProgramProtocol>}, data
      assert_match %{<MCDirectoryTransID>97267598FAE648F28083C23433990FBC</MCDirectoryTransID>}, data
      assert_match %{<SCARecurringPayment>Y</SCARecurringPayment>}, data
      assert_match %{<UCAFInd>4</UCAFInd>}, data
    end.respond_with(successful_purchase_response)
  end

  def test_three_d_secure_data_on_master_sca_recurring_with_invalid_eci
    options_local = {
      three_d_version: '2',
      three_d_secure: {
        eci: '5',
        xid: 'TESTXID',
        cavv: 'AAAEEEDDDSSSAAA2243234',
        ds_transaction_id: '97267598FAE648F28083C23433990FBC',
        version: 2
      },
      sca_recurring: 'Y'
    }

    stub_comms do
      @gateway.authorize(50, credit_card(nil, brand: 'master'), @options.merge(options_local))
    end.check_request do |_endpoint, data, _headers|
      assert_match %{<AuthenticationECIInd>5</AuthenticationECIInd>}, data
      assert_match %{<AAV>AAAEEEDDDSSSAAA2243234</AAV>}, data
      assert_match %{<MCProgramProtocol>2</MCProgramProtocol>}, data
      assert_match %{<MCDirectoryTransID>97267598FAE648F28083C23433990FBC</MCDirectoryTransID>}, data
      assert_match %{<UCAFInd>4</UCAFInd>}, data
    end.respond_with(successful_purchase_response)
  end

  def test_three_d_secure_data_on_american_express_purchase
    stub_comms do
      @gateway.purchase(50, credit_card(nil, brand: 'american_express'), @options.merge(@three_d_secure_options))
    end.check_request do |_endpoint, data, _headers|
      assert_match %{<AuthenticationECIInd>5</AuthenticationECIInd>}, data
      assert_match %{<AEVV>TESTCAVV</AEVV>}, data
      assert_match %{<PymtBrandProgramCode>ASK</PymtBrandProgramCode>}, data
    end.respond_with(successful_purchase_response)
  end

  def test_three_d_secure_data_on_american_express_authorization
    stub_comms do
      @gateway.authorize(50, credit_card(nil, brand: 'american_express'), @options.merge(@three_d_secure_options))
    end.check_request do |_endpoint, data, _headers|
      assert_match %{<AuthenticationECIInd>5</AuthenticationECIInd>}, data
      assert_match %{<AEVV>TESTCAVV</AEVV>}, data
      assert_match %{<PymtBrandProgramCode>ASK</PymtBrandProgramCode>}, data
    end.respond_with(successful_purchase_response)
  end

  def test_currency_exponents
    stub_comms do
      @gateway.purchase(50, credit_card, order_id: '1')
    end.check_request do |_endpoint, data, _headers|
      assert_match %r{<CurrencyExponent>2<\/CurrencyExponent>}, data
    end.respond_with(successful_purchase_response)

    stub_comms do
      @gateway.purchase(50, credit_card, order_id: '1', currency: 'CAD')
    end.check_request do |_endpoint, data, _headers|
      assert_match %r{<CurrencyExponent>2<\/CurrencyExponent>}, data
    end.respond_with(successful_purchase_response)

    stub_comms do
      @gateway.purchase(50, credit_card, order_id: '1', currency: 'JPY')
    end.check_request do |_endpoint, data, _headers|
      assert_match %r{<CurrencyExponent>0<\/CurrencyExponent>}, data
    end.respond_with(successful_purchase_response)
  end

  def test_unauthenticated_response
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    assert response = @gateway.purchase(101, credit_card, order_id: '1')
    assert_instance_of Response, response
    assert_failure response
    assert_equal 'AUTH DECLINED                   12001', response.message
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)

    assert response = @gateway.void('identifier')
    assert_instance_of Response, response
    assert_success response
    assert_nil response.message
  end

  def test_deprecated_void
    @gateway.expects(:ssl_post).returns(successful_void_response)

    assert_deprecation_warning('Calling the void method with an amount parameter is deprecated and will be removed in a future version.') do
      assert response = @gateway.void(50, 'identifier')
      assert_instance_of Response, response
      assert_success response
      assert_nil response.message
    end
  end

  def test_order_id_required
    assert_raise(ArgumentError) do
      @gateway.purchase('101', credit_card)
    end
  end

  def test_order_id_as_number
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    assert_nothing_raised do
      @gateway.purchase(101, credit_card, order_id: 1)
    end
  end

  def test_order_id_format
    response = stub_comms do
      @gateway.purchase(101, credit_card, order_id: ' #101.23,56 $Hi &thére@Friends')
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<OrderID>101-23,56 \$Hi &amp;thre@Fr<\/OrderID>/, data)
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_order_id_format_for_capture
    response = stub_comms do
      @gateway.capture(101, '4A5398CF9B87744GG84A1D30F2F2321C66249416;1001.1', order_id: '#1001.1')
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<OrderID>1001-1<\/OrderID>/, data)
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_numeric_merchant_id_for_caputre
    gateway = ActiveMerchant::Billing::OrbitalGateway.new(
      login: 'login',
      password: 'password',
      merchant_id: 700000123456
    )

    response = stub_comms(gateway) do
      gateway.capture(101, '4A5398CF9B87744GG84A1D30F2F2321C66249416;1', @options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<MerchantID>700000123456<\/MerchantID>/, data)
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_expiry_date
    year = (DateTime.now + 1.year).strftime('%y')
    assert_equal "09#{year}", @gateway.send(:expiry_date, credit_card)
  end

  def test_phone_number
    response = stub_comms do
      @gateway.purchase(50, credit_card, order_id: 1, billing_address: address(phone: '123-456-7890'))
    end.check_request do |_endpoint, data, _headers|
      assert_match(/1234567890/, data)
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_truncates_address
    long_address = '1850 Treebeard Drive in Fangorn Forest by the Fields of Rohan'

    response = stub_comms do
      @gateway.purchase(50, credit_card, order_id: 1, billing_address: address(address1: long_address))
    end.check_request do |_endpoint, data, _headers|
      assert_match(/1850 Treebeard Drive/, data)
      assert_no_match(/Fields of Rohan/, data)
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_truncates_name
    card = credit_card('4242424242424242',
      first_name: 'John',
      last_name: 'Jacob Jingleheimer Smith-Jones')

    response = stub_comms do
      @gateway.purchase(50, card, order_id: 1, billing_address: address)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/John Jacob/, data)
      assert_no_match(/Jones/, data)
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_splits_first_middle_name
    name_test_check = check(name: 'Jane P Doe',
                            account_number: '072403004', account_type: 'checking', routing_number: '072403004')

    response = stub_comms do
      @gateway.purchase(50, name_test_check, order_id: 1, action_code: 'W3')
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<EWSFirstName>Jane</, data)
      assert_match(/<EWSMiddleName>P</, data)
      assert_match(/<EWSLastName>Doe</, data)
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_truncates_city
    long_city = 'Friendly Village of Crooked Creek'

    response = stub_comms do
      @gateway.purchase(50, credit_card, order_id: 1, billing_address: address(city: long_city))
    end.check_request do |_endpoint, data, _headers|
      assert_match(/Friendly Village/, data)
      assert_no_match(/Creek/, data)
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_truncates_phone
    long_phone = '123456789012345'

    response = stub_comms do
      @gateway.purchase(50, credit_card, order_id: 1, billing_address: address(phone: long_phone))
    end.check_request do |_endpoint, data, _headers|
      assert_match(/12345678901234</, data)
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_truncates_zip
    long_zip = '1234567890123'

    response = stub_comms do
      @gateway.purchase(50, credit_card, order_id: 1, billing_address: address(zip: long_zip))
    end.check_request do |_endpoint, data, _headers|
      assert_match(/1234567890</, data)
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_address_format
    address_with_invalid_chars = address(
      address1: '456% M|a^in \\S/treet',
      address2: '|Apt. ^Num\\ber /One%',
      city: 'R^ise o\\f /th%e P|hoenix',
      state: '%O|H\\I/O',
      dest_address1: '2/21%B |B^aker\\ St.',
      dest_address2: 'L%u%xury S|u^i\\t/e',
      dest_city: '/Winn/i%p|e^g\\',
      dest_zip: 'A1A 2B2',
      dest_state: '^MB'
    )

    response = stub_comms do
      @gateway.purchase(50, credit_card, order_id: 1,
                        billing_address: address_with_invalid_chars)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/456 Main Street</, data)
      assert_match(/Apt. Number One</, data)
      assert_match(/Rise of the Phoenix</, data)
      assert_match(/OH</, data)
      assert_match(/221B Baker St.</, data)
      assert_match(/Luxury Suite</, data)
      assert_match(/Winnipeg</, data)
      assert_match(/MB</, data)
    end.respond_with(successful_purchase_response)
    assert_success response

    response = stub_comms do
      assert_deprecation_warning do
        @gateway.add_customer_profile(credit_card,
          billing_address: address_with_invalid_chars)
      end
    end.check_request do |_endpoint, data, _headers|
      assert_match(/456 Main Street</, data)
      assert_match(/Apt. Number One</, data)
      assert_match(/Rise of the Phoenix</, data)
    end.respond_with(successful_profile_response)
    assert_success response
  end

  def test_truncates_by_byte_length
    card = credit_card('4242424242424242',
      first_name: 'John',
      last_name: 'Jacob Jingleheimer Smith-Jones')

    long_address = address(
      address1: '456 Stréêt Name is Really Long',
      address2: 'Apårtmeñt 123456789012345678901',
      city: '¡Vancouver-by-the-sea!',
      state: 'ßC',
      zip: 'Postäl Cøde',
      dest_name: 'Pierré von Bürgermeister de Queso',
      dest_address1: '9876 Stréêt Name is Really Long',
      dest_address2: 'Apårtmeñt 987654321098765432109',
      dest_city: 'Montréal-of-the-south!',
      dest_state: 'Oñtario',
      dest_zip: 'Postäl Zïps'
    )

    response = stub_comms do
      @gateway.purchase(50, card, order_id: 1,
                        billing_address: long_address)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/456 Stréêt Name is Really Lo</, data)
      assert_match(/Apårtmeñt 123456789012345678</, data)
      assert_match(/¡Vancouver-by-the-s</, data)
      assert_match(/ß</, data)
      assert_match(/Postäl C</, data)
      assert_match(/Pierré von Bürgermeister de </, data)
      assert_match(/9876 Stréêt Name is Really L</, data)
      assert_match(/Apårtmeñt 987654321098765432</, data)
      assert_match(/Montréal-of-the-sou</, data)
      assert_match(/O</, data)
      assert_match(/Postäl Z</, data)
    end.respond_with(successful_purchase_response)
    assert_success response

    response = stub_comms do
      assert_deprecation_warning do
        @gateway.add_customer_profile(credit_card,
          billing_address: long_address)
      end
    end.check_request do |_endpoint, data, _headers|
      assert_match(/456 Stréêt Name is Really Lo</, data)
      assert_match(/Apårtmeñt 123456789012345678</, data)
      assert_match(/¡Vancouver-by-the-s</, data)
      assert_match(/ß</, data)
      assert_match(/Postäl C</, data)
    end.respond_with(successful_profile_response)
    assert_success response
  end

  def test_nil_address_values_should_not_throw_exceptions
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    address_options = {
      address1: nil,
      address2: nil,
      city: nil,
      state: nil,
      zip: nil,
      email: nil,
      phone: nil,
      fax: nil
    }

    response = @gateway.purchase(50, credit_card, order_id: 1, billing_address: address(address_options))
    assert_success response
  end

  def test_dest_address
    billing_address = address(
      dest_zip: '90001',
      dest_address1: '456 Main St.',
      dest_city: 'Somewhere',
      dest_state: 'CA',
      dest_name: 'Joan Smith',
      dest_phone: '(123) 456-7890',
      dest_country: 'US'
    )

    response = stub_comms do
      @gateway.purchase(50, credit_card, order_id: 1,
                        billing_address: billing_address)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<AVSDestzip>90001/, data)
      assert_match(/<AVSDestaddress1>456 Main St./, data)
      assert_match(/<AVSDestaddress2/, data)
      assert_match(/<AVSDestcity>Somewhere/, data)
      assert_match(/<AVSDeststate>CA/, data)
      assert_match(/<AVSDestname>Joan Smith/, data)
      assert_match(/<AVSDestphoneNum>1234567890/, data)
      assert_match(/<AVSDestcountryCode>US/, data)
    end.respond_with(successful_purchase_response)
    assert_success response

    # non-AVS country
    response = stub_comms do
      @gateway.purchase(50, credit_card, order_id: 1,
                        billing_address: billing_address.merge(dest_country: 'BR'))
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<AVSDestcountryCode></, data)
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_name_sends_for_credit_card_with_address
    address = address(
      dest_zip: '90001',
      dest_address1: '456 Main St.',
      dest_city: 'Somewhere',
      dest_state: 'CA',
      dest_name: 'Joan Smith',
      dest_phone: '(123) 456-7890',
      dest_country: 'US'
    )

    card = credit_card('4242424242424242',
      first_name: 'John',
      last_name: 'Jacob Jingleheimer Smith-Jones')

    response = stub_comms do
      @gateway.purchase(50, card, order_id: 1, address: address)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/John Jacob/, data)
      assert_no_match(/Jones/, data)
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_name_sends_for_echeck_with_address
    name_test_check = check(name: 'John Jacob Jingleheimer Smith-Jones',
                            account_number: '072403004', account_type: 'checking', routing_number: '072403004')

    response = stub_comms do
      @gateway.purchase(50, name_test_check, order_id: 1)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/John Jacob/, data)
      assert_no_match(/Jones/, data)
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_name_sends_for_echeck_with_no_address
    name_test_check = check(name: 'John Jacob Jingleheimer Smith-Jones',
                            account_number: '072403004', account_type: 'checking', routing_number: '072403004')

    response = stub_comms do
      @gateway.purchase(50, name_test_check, order_id: 1, address: nil, billing_address: nil)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/John Jacob/, data)
      assert_no_match(/Jones/, data)
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_does_not_send_for_credit_card_with_no_address
    card = credit_card('4242424242424242',
      first_name: 'John',
      last_name: 'Jacob Jingleheimer Smith-Jones')

    response = stub_comms do
      @gateway.purchase(50, card, order_id: 1, address: nil, billing_address: nil)
    end.check_request do |_endpoint, data, _headers|
      assert_no_match(/John Jacob/, data)
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_avs_name_falls_back_to_billing_address
    billing_address = address(
      zip: '90001',
      address1: '456 Main St.',
      city: 'Somewhere',
      state: 'CA',
      name: 'Joan Smith',
      phone: '(123) 456-7890',
      country: 'US'
    )

    card = credit_card('4242424242424242',
      first_name: nil,
      last_name: '')

    response = stub_comms do
      @gateway.purchase(50, card, order_id: 1, billing_address: billing_address)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/Joan Smith/, data)
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_completely_blank_name
    billing_address = address(
      zip: '90001',
      address1: '456 Main St.',
      city: 'Somewhere',
      state: 'CA',
      name: nil,
      phone: '(123) 456-7890',
      country: 'US'
    )

    card = credit_card('4242424242424242',
      first_name: nil,
      last_name: nil)

    response = stub_comms do
      @gateway.purchase(50, card, order_id: 1, billing_address: billing_address)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/\<AVSname\/>\n/, data)
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_successful_purchase_with_negative_stored_credentials_indicator
    stub_comms do
      @gateway.purchase(50, credit_card, @options.merge(mit_stored_credential_ind: 'N'))
    end.check_request do |_endpoint, data, _headers|
      assert_no_match(/<MITMsgType>/, data)
      assert_no_match(/<MITStoredCredentialInd>/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_successful_purchase_with_stored_credentials
    stub_comms do
      @gateway.purchase(50, credit_card, @options.merge(@options_stored_credentials))
    end.check_request do |_endpoint, data, _headers|
      assert_match %{<MITMsgType>#{@options_stored_credentials[:mit_msg_type]}</MITMsgType>}, data
      assert_match %{<MITStoredCredentialInd>#{@options_stored_credentials[:mit_stored_credential_ind]}</MITStoredCredentialInd>}, data
      assert_match %{<MITSubmittedTransactionID>#{@options_stored_credentials[:mit_submitted_transaction_id]}</MITSubmittedTransactionID>}, data
    end.respond_with(successful_purchase_response)
  end

  def test_stored_credential_recurring_cit_initial
    options = stored_credential_options(:cardholder, :recurring, :initial)
    response = stub_comms do
      @gateway.purchase(50, credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<MITMsgType>CSTO</, data)
      assert_match(/<MITStoredCredentialInd>Y</, data)
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_stored_credential_recurring_cit_used
    credit_card.verification_value = nil
    options = stored_credential_options(:cardholder, :recurring, id: 'abc123')
    response = stub_comms do
      @gateway.purchase(50, credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<MITMsgType>CREC</, data)
      assert_match(/<MITStoredCredentialInd>Y</, data)
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_stored_credential_recurring_mit_initial
    options = stored_credential_options(:merchant, :recurring, :initial)
    response = stub_comms do
      @gateway.purchase(50, credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<MITMsgType>CSTO</, data)
      assert_match(/<MITStoredCredentialInd>Y</, data)
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_stored_credential_recurring_mit_used
    credit_card.verification_value = nil
    options = stored_credential_options(:merchant, :recurring, id: 'abc123')
    response = stub_comms do
      @gateway.purchase(50, credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<MITMsgType>MREC</, data)
      assert_match(/<MITStoredCredentialInd>Y</, data)
      assert_match(/<MITSubmittedTransactionID>abc123</, data)
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_stored_credential_unscheduled_cit_initial
    options = stored_credential_options(:cardholder, :unscheduled, :initial)
    response = stub_comms do
      @gateway.purchase(50, credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<MITMsgType>CSTO</, data)
      assert_match(/<MITStoredCredentialInd>Y</, data)
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_stored_credential_unscheduled_cit_used
    credit_card.verification_value = nil
    options = stored_credential_options(:cardholder, :unscheduled, id: 'abc123')
    response = stub_comms do
      @gateway.purchase(50, credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<MITMsgType>CUSE</, data)
      assert_match(/<MITStoredCredentialInd>Y</, data)
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_stored_credential_unscheduled_mit_initial
    options = stored_credential_options(:merchant, :unscheduled, :initial)
    response = stub_comms do
      @gateway.purchase(50, credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<MITMsgType>CSTO</, data)
      assert_match(/<MITStoredCredentialInd>Y</, data)
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_stored_credential_unscheduled_mit_used
    credit_card.verification_value = nil
    options = stored_credential_options(:merchant, :unscheduled, id: 'abc123')
    response = stub_comms do
      @gateway.purchase(50, credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<MITMsgType>MUSE</, data)
      assert_match(/<MITStoredCredentialInd>Y</, data)
      assert_match(/<MITSubmittedTransactionID>abc123</, data)
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_stored_credential_installment_cit_initial
    options = stored_credential_options(:cardholder, :installment, :initial)
    response = stub_comms do
      @gateway.purchase(50, credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<MITMsgType>CSTO</, data)
      assert_match(/<MITStoredCredentialInd>Y</, data)
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_stored_credential_installment_cit_used
    credit_card.verification_value = nil
    options = stored_credential_options(:cardholder, :installment, id: 'abc123')
    response = stub_comms do
      @gateway.purchase(50, credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<MITMsgType>CINS</, data)
      assert_match(/<MITStoredCredentialInd>Y</, data)
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_stored_credential_installment_mit_initial
    options = stored_credential_options(:merchant, :installment, :initial)
    response = stub_comms do
      @gateway.purchase(50, credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<MITMsgType>CSTO</, data)
      assert_match(/<MITStoredCredentialInd>Y</, data)
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_stored_credential_installment_mit_used
    credit_card.verification_value = nil
    options = stored_credential_options(:merchant, :installment, id: 'abc123')
    response = stub_comms do
      @gateway.purchase(50, credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<MITMsgType>MINS</, data)
      assert_match(/<MITStoredCredentialInd>Y</, data)
      assert_match(/<MITSubmittedTransactionID>abc123</, data)
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_successful_purchase_with_overridden_normalized_stored_credentials
    stub_comms do
      @gateway.purchase(50, credit_card, @options.merge(@normalized_mit_stored_credential).merge(@options_stored_credentials))
    end.check_request do |_endpoint, data, _headers|
      assert_match %{<MITMsgType>MRSB</MITMsgType>}, data
      assert_match %{<MITStoredCredentialInd>Y</MITStoredCredentialInd>}, data
      assert_match %{<MITSubmittedTransactionID>123456abcdef</MITSubmittedTransactionID>}, data
    end.respond_with(successful_purchase_response)
  end

  def test_default_managed_billing
    response = stub_comms do
      assert_deprecation_warning(Gateway::RECURRING_DEPRECATION_MESSAGE) do
        assert_deprecation_warning do
          @gateway.add_customer_profile(credit_card, managed_billing: { start_date: '10-10-2014' })
        end
      end
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<MBType>R/, data)
      assert_match(/<MBOrderIdGenerationMethod>IO/, data)
      assert_match(/<MBRecurringStartDate>10102014/, data)
      assert_match(/<MBRecurringNoEndDateFlag>N/, data)
    end.respond_with(successful_profile_response)
    assert_success response
  end

  def test_managed_billing
    response = stub_comms do
      assert_deprecation_warning(Gateway::RECURRING_DEPRECATION_MESSAGE) do
        assert_deprecation_warning do
          @gateway.add_customer_profile(credit_card,
            managed_billing: {
              start_date: '10-10-2014',
              end_date: '10-10-2015',
              max_dollar_value: 1500,
              max_transactions: 12
            })
        end
      end
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<MBType>R/, data)
      assert_match(/<MBOrderIdGenerationMethod>IO/, data)
      assert_match(/<MBRecurringStartDate>10102014/, data)
      assert_match(/<MBRecurringEndDate>10102015/, data)
      assert_match(/<MBMicroPaymentMaxDollarValue>1500/, data)
      assert_match(/<MBMicroPaymentMaxTransactions>12/, data)
    end.respond_with(successful_profile_response)
    assert_success response
  end

  def test_dont_send_customer_data_by_default
    response = stub_comms do
      @gateway.purchase(50, credit_card, order_id: 1)
    end.check_request do |_endpoint, data, _headers|
      assert_no_match(/<CustomerRefNum>K1C2N6/, data)
      assert_no_match(/<CustomerProfileFromOrderInd>456 My Street/, data)
      assert_no_match(/<CustomerProfileOrderOverrideInd>Apt 1/, data)
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_send_customer_data_when_customer_profiles_is_enabled
    @gateway.options[:customer_profiles] = true
    response = stub_comms do
      @gateway.purchase(50, credit_card, order_id: 1)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<CustomerProfileFromOrderInd>A/, data)
      assert_match(/<CustomerProfileOrderOverrideInd>NO/, data)
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_send_customer_data_when_customer_ref_is_provided
    @gateway.options[:customer_profiles] = true
    response = stub_comms do
      @gateway.purchase(50, credit_card, order_id: 1, customer_ref_num: @customer_ref_num)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<CustomerRefNum>ABC/, data)
      assert_match(/<CustomerProfileFromOrderInd>S/, data)
      assert_match(/<CustomerProfileOrderOverrideInd>NO/, data)
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_send_card_indicators_when_provided_purchase
    response = stub_comms do
      @gateway.purchase(50, credit_card, order_id: 1, card_indicators: @options[:card_indicators])
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<CardIndicators>y/, data)
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_send_card_indicators_when_provided_authorize
    response = stub_comms do
      @gateway.authorize(50, credit_card, order_id: 1, card_indicators: @options[:card_indicators])
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<CardIndicators>y/, data)
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_dont_send_customer_profile_from_order_ind_for_profile_purchase
    @gateway.options[:customer_profiles] = true
    response = stub_comms do
      @gateway.purchase(50, nil, order_id: 1, customer_ref_num: @customer_ref_num)
    end.check_request do |_endpoint, data, _headers|
      assert_no_match(/<CustomerProfileFromOrderInd>/, data)
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_dont_send_customer_profile_from_order_ind_for_profile_authorize
    @gateway.options[:customer_profiles] = true
    response = stub_comms do
      @gateway.authorize(50, nil, order_id: 1, customer_ref_num: @customer_ref_num)
    end.check_request do |_endpoint, data, _headers|
      assert_no_match(/<CustomerProfileFromOrderInd>/, data)
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_currency_code_and_exponent_are_set_for_profile_purchase
    @gateway.options[:customer_profiles] = true
    response = stub_comms do
      @gateway.purchase(50, nil, order_id: 1, customer_ref_num: @customer_ref_num)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<CustomerRefNum>ABC/, data)
      assert_match(/<CurrencyCode>124/, data)
      assert_match(/<CurrencyExponent>2/, data)
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_currency_code_and_exponent_are_set_for_profile_authorizations
    @gateway.options[:customer_profiles] = true
    response = stub_comms do
      @gateway.authorize(50, nil, order_id: 1, customer_ref_num: @customer_ref_num)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<CustomerRefNum>ABC/, data)
      assert_match(/<CurrencyCode>124/, data)
      assert_match(/<CurrencyExponent>2/, data)
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_successful_authorize_with_echeck
    @gateway.expects(:ssl_post).returns(successful_authorize_with_echeck_response)

    assert response = @gateway.authorize(50, @echeck, order_id: '2')
    assert_instance_of Response, response
    assert_equal 'Approved', response.message
    assert_success response
    assert_equal '5F8E8D2B077217F3EF1ACD3B61610E4CD12954A3;2', response.authorization
  end

  def test_failed_authorize_with_echeck
    @gateway.expects(:ssl_post).returns(failed_echeck_for_invalid_amount_response)

    assert response = @gateway.authorize(-1, @echeck, order_id: '9baedc697f2cf06457de78')
    assert_instance_of Response, response
    assert_failure response
    assert_equal 'Error validating amount. Must be numeric, equal to zero or greater [-1]', response.message
    assert_equal '885', response.params['proc_status']
  end

  def test_successful_refund_with_echeck
    @gateway.expects(:ssl_post).returns(successful_refund_with_echeck_response)

    assert response = @gateway.refund(50, '1;2', @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal '1', response.params['approval_status']
  end

  def test_failed_refund_with_echeck
    @gateway.expects(:ssl_post).returns(failed_refund_with_echeck_response)

    assert response = @gateway.refund(50, '1;2', @options)
    assert_instance_of Response, response
    assert_failure response
    assert_equal 'Refund Transactions By TxRefNum Are Only Valid When The Original Transaction Was An AUTH Or AUTH CAPTURE.', response.message
    assert_equal '9806', response.params['proc_status']
  end

  def test_successful_credit
    @gateway.expects(:ssl_post).returns(successful_credit_response)

    assert response = @gateway.credit(100, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal '1', response.params['approval_status']
  end

  def test_always_send_avs_for_echeck
    response = stub_comms do
      @gateway.purchase(50, @echeck, order_id: 1, address: nil, billing_address: address(country: nil))
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<AVSname>Jim Smith</, data)
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_send_address_details_for_united_states
    response = stub_comms do
      @gateway.purchase(50, credit_card, order_id: 1, billing_address: address)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<AVSzip>K1C2N6/, data)
      assert_match(/<AVSaddress1>456 My Street/, data)
      assert_match(/<AVSaddress2>Apt 1/, data)
      assert_match(/<AVScity>Ottawa/, data)
      assert_match(/<AVSstate>ON/, data)
      assert_match(/<AVSphoneNum>5555555555/, data)
      assert_match(/<AVSname>Longbob Longsen/, data)
      assert_match(/<AVScountryCode>CA/, data)
    end.respond_with(successful_purchase_response)
    assert_success response
    assert_equal 'Y', response.avs_result['street_match']
    assert_equal 'Y', response.avs_result['postal_match']
  end

  def test_dont_send_address_details_for_germany
    response = stub_comms do
      @gateway.purchase(50, credit_card, order_id: 1, billing_address: address(country: 'DE'))
    end.check_request do |_endpoint, data, _headers|
      assert_no_match(/<AVSzip>K1C2N6/, data)
      assert_no_match(/<AVSaddress1>456 My Street/, data)
      assert_no_match(/<AVSaddress2>Apt 1/, data)
      assert_no_match(/<AVScity>Ottawa/, data)
      assert_no_match(/<AVSstate>ON/, data)
      assert_no_match(/<AVSphoneNum>5555555555/, data)
      assert_match(/<AVSname>Longbob Longsen/, data)
      assert_match(/<AVScountryCode(\/>|><\/AVScountryCode>)/, data)
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_allow_sending_avs_parts_when_no_country_specified
    response = stub_comms do
      @gateway.purchase(50, credit_card, order_id: 1, billing_address: address(country: nil))
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<AVSzip>K1C2N6/, data)
      assert_match(/<AVSaddress1>456 My Street/, data)
      assert_match(/<AVSaddress2>Apt 1/, data)
      assert_match(/<AVScity>Ottawa/, data)
      assert_match(/<AVSstate>ON/, data)
      assert_match(/<AVSphoneNum>5555555555/, data)
      assert_match(/<AVSname>Longbob Longsen/, data)
      assert_match(/<AVScountryCode(\/>|><\/AVScountryCode>)/, data)
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_american_requests_adhere_to_xml_schema
    response = stub_comms do
      @gateway.purchase(50, credit_card, order_id: 1, billing_address: address)
    end.check_request do |_endpoint, data, _headers|
      schema_file = File.read("#{File.dirname(__FILE__)}/../../schema/orbital/Request_PTI83.xsd")
      doc = Nokogiri::XML(data)
      xsd = Nokogiri::XML::Schema(schema_file)
      assert xsd.valid?(doc), 'Request does not adhere to DTD'
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_german_requests_adhere_to_xml_schema
    response = stub_comms do
      @gateway.purchase(50, credit_card, order_id: 1, billing_address: address(country: 'DE'))
    end.check_request do |_endpoint, data, _headers|
      schema_file = File.read("#{File.dirname(__FILE__)}/../../schema/orbital/Request_PTI83.xsd")
      doc = Nokogiri::XML(data)
      xsd = Nokogiri::XML::Schema(schema_file)
      assert xsd.valid?(doc), 'Request does not adhere to DTD'
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_add_customer_profile
    response = stub_comms do
      assert_deprecation_warning do
        @gateway.add_customer_profile(credit_card)
      end
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<CustomerProfileAction>C/, data)
      assert_match(/<CustomerName>Longbob Longsen/, data)
    end.respond_with(successful_profile_response)
    assert_success response
  end

  def test_add_customer_profile_with_email
    response = stub_comms do
      assert_deprecation_warning do
        @gateway.add_customer_profile(credit_card, { billing_address: { email: 'xiaobozzz@example.com' } })
      end
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<CustomerProfileAction>C/, data)
      assert_match(/<CustomerEmail>xiaobozzz@example.com/, data)
    end.respond_with(successful_profile_response)
    assert_success response
  end

  def test_update_customer_profile
    response = stub_comms do
      assert_deprecation_warning do
        @gateway.update_customer_profile(credit_card)
      end
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<CustomerProfileAction>U/, data)
      assert_match(/<CustomerName>Longbob Longsen/, data)
    end.respond_with(successful_profile_response)
    assert_success response
  end

  def test_retrieve_customer_profile
    response = stub_comms do
      assert_deprecation_warning do
        @gateway.retrieve_customer_profile(@customer_ref_num)
      end
    end.check_request do |_endpoint, data, _headers|
      assert_no_match(/<CustomerName>Longbob Longsen/, data)
      assert_match(/<CustomerProfileAction>R/, data)
      assert_match(/<CustomerRefNum>ABC/, data)
    end.respond_with(successful_profile_response)
    assert_success response
  end

  def test_delete_customer_profile
    response = stub_comms do
      assert_deprecation_warning do
        @gateway.delete_customer_profile(@customer_ref_num)
      end
    end.check_request do |_endpoint, data, _headers|
      assert_no_match(/<CustomerName>Longbob Longsen/, data)
      assert_match(/<CustomerProfileAction>D/, data)
      assert_match(/<CustomerRefNum>ABC/, data)
    end.respond_with(successful_profile_response)
    assert_success response
  end

  def test_attempts_seconday_url
    @gateway.expects(:ssl_post).with(OrbitalGateway.test_url, anything, anything).raises(ActiveMerchant::ConnectionError.new('message', nil))
    @gateway.expects(:ssl_post).with(OrbitalGateway.secondary_test_url, anything, anything).returns(successful_purchase_response)

    response = @gateway.purchase(50, credit_card, order_id: '1')
    assert_success response
  end

  # retry_logic true and some value for trace_number.
  def test_headers_when_retry_logic_is_enabled
    @gateway.options[:retry_logic] = true
    response = stub_comms do
      @gateway.purchase(50, credit_card, order_id: 1, trace_number: 1)
    end.check_request do |_endpoint, _data, headers|
      assert_equal('1', headers['Trace-number'])
      assert_equal('merchant_id', headers['Merchant-Id'])
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_retry_logic_not_enabled
    @gateway.options[:retry_logic] = false
    response = stub_comms do
      @gateway.purchase(50, credit_card, order_id: 1, trace_number: 1)
    end.check_request do |_endpoint, _data, headers|
      assert_equal(false, headers.has_key?('Trace-number'))
      assert_equal(false, headers.has_key?('Merchant-Id'))
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_headers_when_retry_logic_param_exists
    response = stub_comms do
      @gateway.purchase(50, credit_card, order_id: 1, retry_logic: 'true', trace_number: 1)
    end.check_request do |_endpoint, _data, headers|
      assert_equal('1', headers['Trace-number'])
      assert_equal('merchant_id', headers['Merchant-Id'])
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_retry_logic_when_param_nonexistant
    response = stub_comms do
      @gateway.purchase(50, credit_card, order_id: 1, trace_number: 1)
    end.check_request do |_endpoint, _data, headers|
      assert_equal(false, headers.has_key?('Trace-number'))
      assert_equal(false, headers.has_key?('Merchant-Id'))
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_headers_when_trace_number_nonexistant
    response = stub_comms do
      @gateway.purchase(50, credit_card, order_id: 1, retry_logic: 'true')
    end.check_request do |_endpoint, _data, headers|
      assert_equal(nil, headers['Trace-number'])
      assert_equal(nil, headers['Merchant-Id'])
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_payment_delivery_when_param_correct
    response = stub_comms do
      @gateway.purchase(50, @echeck, order_id: 1, payment_delivery: 'A')
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<BankPmtDelv>A/, data)
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_payment_delivery_when_no_payment_delivery_param
    response = stub_comms do
      @gateway.purchase(50, @echeck, order_id: 1)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<BankPmtDelv>B/, data)
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  ActiveMerchant::Billing::OrbitalGateway::APPROVED.each do |resp_code|
    define_method "test_approval_response_code_#{resp_code}" do
      @gateway.expects(:ssl_post).returns(successful_purchase_response(resp_code))

      assert response = @gateway.purchase(50, credit_card, order_id: '1')
      assert_instance_of Response, response
      assert_success response
    end
  end

  def test_account_num_is_removed_from_response
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(50, credit_card, order_id: '1')
    assert_instance_of Response, response
    assert_success response
    assert_nil response.params['account_num']
  end

  def test_cc_account_num_is_removed_from_response
    @gateway.expects(:ssl_post).returns(successful_profile_response)

    response = nil

    assert_deprecation_warning do
      response = @gateway.add_customer_profile(credit_card,
        billing_address: address)
    end

    assert_instance_of Response, response
    assert_success response
    assert_nil response.params['cc_account_num']
  end

  def test_successful_verify
    response = stub_comms do
      @gateway.verify(credit_card, @options)
    end.respond_with(successful_purchase_response, successful_purchase_response)
    assert_success response
    assert_equal '4A5398CF9B87744GG84A1D30F2F2321C66249416;1', response.authorization
    assert_equal 'Approved', response.message
  end

  def test_successful_verify_and_failed_void
    response = stub_comms do
      @gateway.verify(credit_card, @options)
    end.respond_with(successful_purchase_response, failed_purchase_response)
    assert_success response
    assert_equal '4A5398CF9B87744GG84A1D30F2F2321C66249416;1', response.authorization
    assert_equal 'Approved', response.message
  end

  def test_failed_verify
    response = stub_comms do
      @gateway.verify(credit_card, @options)
    end.respond_with(failed_purchase_response, failed_purchase_response)
    assert_failure response
    assert_equal 'AUTH DECLINED                   12001', response.message
  end

  def test_cvv_indicator_present_for_visas_with_cvvs
    stub_comms do
      @gateway.purchase(50, credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_match %r{<CardSecValInd>1<\/CardSecValInd>}, data
      assert_match %r{<CardSecVal>123<\/CardSecVal>}, data
    end.respond_with(successful_purchase_response)
  end

  def test_cvv_indicator_absent_for_recurring
    stub_comms do
      @gateway.purchase(50, credit_card(nil, { verification_value: nil }), @options)
    end.check_request do |_endpoint, data, _headers|
      assert_no_match %r{<CardSecValInd>}, data
      assert_no_match %r{<CardSecVal>}, data
    end.respond_with(successful_purchase_response)
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def stored_credential_options(*args, id: nil)
    {
      order_id: '#1001',
      description: 'AM test',
      currency: 'GBP',
      customer: '123',
      stored_credential: stored_credential(*args, id: id)
    }
  end

  def successful_purchase_response(resp_code = '00')
    %Q{<?xml version="1.0" encoding="UTF-8"?><Response><NewOrderResp><IndustryType></IndustryType><MessageType>AC</MessageType><MerchantID>700000000000</MerchantID><TerminalID>001</TerminalID><CardBrand>VI</CardBrand><AccountNum>4111111111111111</AccountNum><OrderID>1</OrderID><TxRefNum>4A5398CF9B87744GG84A1D30F2F2321C66249416</TxRefNum><TxRefIdx>1</TxRefIdx><ProcStatus>0</ProcStatus><ApprovalStatus>1</ApprovalStatus><RespCode>#{resp_code}</RespCode><AVSRespCode>H </AVSRespCode><CVV2RespCode>N</CVV2RespCode><AuthCode>091922</AuthCode><RecurringAdviceCd></RecurringAdviceCd><CAVVRespCode></CAVVRespCode><StatusMsg>Approved</StatusMsg><RespMsg></RespMsg><HostRespCode>00</HostRespCode><HostAVSRespCode>Y</HostAVSRespCode><HostCVV2RespCode>N</HostCVV2RespCode><CustomerRefNum></CustomerRefNum><CustomerName></CustomerName><ProfileProcStatus></ProfileProcStatus><CustomerProfileMessage></CustomerProfileMessage><RespTime>144951</RespTime></NewOrderResp></Response>}
  end

  def failed_purchase_response
    '<?xml version="1.0" encoding="UTF-8"?><Response><NewOrderResp><IndustryType></IndustryType><MessageType>AC</MessageType><MerchantID>700000000000</MerchantID><TerminalID>001</TerminalID><CardBrand>VI</CardBrand><AccountNum>4000300011112220</AccountNum><OrderID>1</OrderID><TxRefNum>4A5398CF9B87744GG84A1D30F2F2321C66249416</TxRefNum><TxRefIdx>0</TxRefIdx><ProcStatus>0</ProcStatus><ApprovalStatus>0</ApprovalStatus><RespCode>05</RespCode><AVSRespCode>G </AVSRespCode><CVV2RespCode>N</CVV2RespCode><AuthCode></AuthCode><RecurringAdviceCd></RecurringAdviceCd><CAVVRespCode></CAVVRespCode><StatusMsg>Do Not Honor</StatusMsg><RespMsg>AUTH DECLINED                   12001</RespMsg><HostRespCode>05</HostRespCode><HostAVSRespCode>N</HostAVSRespCode><HostCVV2RespCode>N</HostCVV2RespCode><CustomerRefNum></CustomerRefNum><CustomerName></CustomerName><ProfileProcStatus></ProfileProcStatus><CustomerProfileMessage></CustomerProfileMessage><RespTime>150214</RespTime></NewOrderResp></Response>'
  end

  def successful_profile_response
    '<?xml version="1.0" encoding="UTF-8"?><Response><ProfileResp><CustomerBin>000001</CustomerBin><CustomerMerchantID>700000000000</CustomerMerchantID><CustomerName>Longbob Longsen</CustomerName><CustomerRefNum>ABC</CustomerRefNum><CustomerProfileAction>CREATE</CustomerProfileAction><ProfileProcStatus>0</ProfileProcStatus><CustomerProfileMessage>Profile Request Processed</CustomerProfileMessage><CustomerAccountType>CC</CustomerAccountType><Status>A</Status><CCAccountNum>4111111111111111</CCAccountNum><RespTime/></ProfileResp></Response>'
  end

  def successful_void_response
    '<?xml version="1.0" encoding="UTF-8"?><Response><ReversalResp><MerchantID>700000208761</MerchantID><TerminalID>001</TerminalID><OrderID>2</OrderID><TxRefNum>50FB1C41FEC9D016FF0BEBAD0884B174AD0853B0</TxRefNum><TxRefIdx>1</TxRefIdx><OutstandingAmt>0</OutstandingAmt><ProcStatus>0</ProcStatus><StatusMsg></StatusMsg><RespTime>01192013172049</RespTime></ReversalResp></Response>'
  end

  def successful_purchase_with_echeck_response
    '<?xml version="1.0" encoding="UTF-8"?><Response><NewOrderResp><IndustryType></IndustryType><MessageType>AC</MessageType><MerchantID>041756</MerchantID><TerminalID>001</TerminalID><CardBrand>EC</CardBrand><AccountNum></AccountNum><OrderID>9baedc697f2cf06457de78</OrderID><TxRefNum>5F8E8BEE7299FD339A38F70CFF6E5D010EF55498</TxRefNum><TxRefIdx>2</TxRefIdx><ProcStatus>0</ProcStatus><ApprovalStatus>1</ApprovalStatus><RespCode>00</RespCode><AVSRespCode>3 </AVSRespCode><CVV2RespCode> </CVV2RespCode><AuthCode>123456</AuthCode><RecurringAdviceCd></RecurringAdviceCd><CAVVRespCode></CAVVRespCode><StatusMsg>Approved</StatusMsg><RespMsg></RespMsg><HostRespCode>102</HostRespCode><HostAVSRespCode>  </HostAVSRespCode><HostCVV2RespCode>  </HostCVV2RespCode><CustomerRefNum></CustomerRefNum><CustomerName></CustomerName><ProfileProcStatus></ProfileProcStatus><CustomerProfileMessage></CustomerProfileMessage><RespTime>030414</RespTime><PartialAuthOccurred></PartialAuthOccurred><RequestedAmount></RequestedAmount><RedeemedAmount></RedeemedAmount><RemainingBalance></RemainingBalance><CountryFraudFilterStatus></CountryFraudFilterStatus><IsoCountryCode></IsoCountryCode></NewOrderResp></Response>'
  end

  def successful_force_capture_with_echeck_response
    '<?xml version="1.0" encoding="UTF-8"?><Response><NewOrderResp><IndustryType></IndustryType><MessageType>FC</MessageType><MerchantID>041756</MerchantID><TerminalID>001</TerminalID><CardBrand>EC</CardBrand><AccountNum></AccountNum><OrderID>2930847bc732eb4e8102cf</OrderID><TxRefNum>5F8ED3D950A43BD63369845D5385B6354C3654B4</TxRefNum><TxRefIdx>2</TxRefIdx><ProcStatus>0</ProcStatus><ApprovalStatus>1</ApprovalStatus><RespCode>00</RespCode><AVSRespCode></AVSRespCode><CVV2RespCode></CVV2RespCode><AuthCode></AuthCode><RecurringAdviceCd></RecurringAdviceCd><CAVVRespCode></CAVVRespCode><StatusMsg>Approved and Completed</StatusMsg><RespMsg>APPROVAL        </RespMsg><HostRespCode></HostRespCode><HostAVSRespCode></HostAVSRespCode><HostCVV2RespCode></HostCVV2RespCode><CustomerRefNum></CustomerRefNum><CustomerName></CustomerName><ProfileProcStatus></ProfileProcStatus><CustomerProfileMessage></CustomerProfileMessage><RespTime>081105</RespTime><PartialAuthOccurred></PartialAuthOccurred><RequestedAmount></RequestedAmount><RedeemedAmount></RedeemedAmount><RemainingBalance></RemainingBalance><CountryFraudFilterStatus></CountryFraudFilterStatus><IsoCountryCode></IsoCountryCode></NewOrderResp></Response>'
  end

  def successful_force_capture_with_echeck_prenote_response
    '<?xml version="1.0" encoding="UTF-8"?><Response><NewOrderResp><IndustryType></IndustryType><MessageType>FC</MessageType><MerchantID>041756</MerchantID><TerminalID>001</TerminalID><CardBrand>EC</CardBrand><AccountNum></AccountNum><OrderID>2930847bc732eb4e8102cf</OrderID><TxRefNum>5F8ED3D950A43BD63369845D5385B6354C3654B4</TxRefNum><TxRefIdx>2</TxRefIdx><ProcStatus>0</ProcStatus><ApprovalStatus>1</ApprovalStatus><RespCode>00</RespCode><AVSRespCode></AVSRespCode><CVV2RespCode></CVV2RespCode><AuthCode></AuthCode><RecurringAdviceCd></RecurringAdviceCd><CAVVRespCode></CAVVRespCode><StatusMsg>Approved and Completed</StatusMsg><RespMsg>APPROVAL        </RespMsg><HostRespCode></HostRespCode><HostAVSRespCode></HostAVSRespCode><HostCVV2RespCode></HostCVV2RespCode><CustomerRefNum></CustomerRefNum><CustomerName></CustomerName><ProfileProcStatus></ProfileProcStatus><CustomerProfileMessage></CustomerProfileMessage><RespTime>081105</RespTime><PartialAuthOccurred></PartialAuthOccurred><RequestedAmount></RequestedAmount><RedeemedAmount></RedeemedAmount><RemainingBalance></RemainingBalance><CountryFraudFilterStatus></CountryFraudFilterStatus><IsoCountryCode></IsoCountryCode></NewOrderResp></Response>'
  end

  def failed_force_capture_with_echeck_prenote_response
    '<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><QuickResp><ProcStatus>19784</ProcStatus><StatusMsg> EWS: Invalid Action Code [W7], For Transaction Type [A].</StatusMsg></QuickResp></Response>'
  end

  def failed_echeck_for_invalid_routing_response
    '<?xml version="1.0" encoding="UTF-8"?><Response><QuickResp><ProcStatus>888</ProcStatus><StatusMsg>Invalid ECP Account Route: []. The field is missing, invalid, or it has exceeded the max length of: [9].</StatusMsg></QuickResp></Response>'
  end

  def failed_echeck_for_invalid_amount_response
    '<?xml version="1.0" encoding="UTF-8"?><Response><QuickResp><ProcStatus>885</ProcStatus><StatusMsg>Error validating amount. Must be numeric, equal to zero or greater [-1]</StatusMsg></QuickResp></Response>'
  end

  def successful_authorize_with_echeck_response
    '<?xml version="1.0" encoding="UTF-8"?><Response><NewOrderResp><IndustryType></IndustryType><MessageType>A</MessageType><MerchantID>041756</MerchantID><TerminalID>001</TerminalID><CardBrand>EC</CardBrand><AccountNum></AccountNum><OrderID>2</OrderID><TxRefNum>5F8E8D2B077217F3EF1ACD3B61610E4CD12954A3</TxRefNum><TxRefIdx>0</TxRefIdx><ProcStatus>0</ProcStatus><ApprovalStatus>1</ApprovalStatus><RespCode>00</RespCode><AVSRespCode>3 </AVSRespCode><CVV2RespCode> </CVV2RespCode><AuthCode>123456</AuthCode><RecurringAdviceCd></RecurringAdviceCd><CAVVRespCode></CAVVRespCode><StatusMsg>Approved</StatusMsg><RespMsg></RespMsg><HostRespCode>102</HostRespCode><HostAVSRespCode>  </HostAVSRespCode><HostCVV2RespCode>  </HostCVV2RespCode><CustomerRefNum></CustomerRefNum><CustomerName></CustomerName><ProfileProcStatus></ProfileProcStatus><CustomerProfileMessage></CustomerProfileMessage><RespTime>030931</RespTime><PartialAuthOccurred></PartialAuthOccurred><RequestedAmount></RequestedAmount><RedeemedAmount></RedeemedAmount><RemainingBalance></RemainingBalance><CountryFraudFilterStatus></CountryFraudFilterStatus><IsoCountryCode></IsoCountryCode></NewOrderResp></Response>'
  end

  def successful_refund_with_echeck_response
    '<?xml version="1.0" encoding="UTF-8"?><Response><NewOrderResp><IndustryType></IndustryType><MessageType>R</MessageType><MerchantID>041756</MerchantID><TerminalID>001</TerminalID><CardBrand>EC</CardBrand><AccountNum>XXXXX3004</AccountNum><OrderID>b67774a1bbfe1387f5e185</OrderID><TxRefNum>5F8E8D8A542ED5CC24449BC4CECD337BE05754C2</TxRefNum><TxRefIdx>2</TxRefIdx><ProcStatus>0</ProcStatus><ApprovalStatus>1</ApprovalStatus><RespCode></RespCode><AVSRespCode></AVSRespCode><CVV2RespCode></CVV2RespCode><AuthCode></AuthCode><RecurringAdviceCd></RecurringAdviceCd><CAVVRespCode></CAVVRespCode><StatusMsg></StatusMsg><RespMsg></RespMsg><HostRespCode></HostRespCode><HostAVSRespCode></HostAVSRespCode><HostCVV2RespCode></HostCVV2RespCode><CustomerRefNum></CustomerRefNum><CustomerName></CustomerName><ProfileProcStatus></ProfileProcStatus><CustomerProfileMessage></CustomerProfileMessage><RespTime>031106</RespTime><PartialAuthOccurred></PartialAuthOccurred><RequestedAmount></RequestedAmount><RedeemedAmount></RedeemedAmount><RemainingBalance></RemainingBalance><CountryFraudFilterStatus></CountryFraudFilterStatus><IsoCountryCode></IsoCountryCode></NewOrderResp></Response>'
  end

  def failed_refund_with_echeck_response
    '<?xml version="1.0" encoding="UTF-8"?><Response><QuickResp><ProcStatus>9806</ProcStatus><StatusMsg>Refund Transactions By TxRefNum Are Only Valid When The Original Transaction Was An AUTH Or AUTH CAPTURE.</StatusMsg></QuickResp></Response>'
  end

  def successful_credit_response
    '<?xml version="1.0" encoding="UTF-8"?><Response><NewOrderResp><IndustryType></IndustryType><MessageType>R</MessageType><MerchantID>253997</MerchantID><TerminalID>001</TerminalID><CardBrand>MC</CardBrand><AccountNum>XXXXX5454</AccountNum><OrderID>6102f8d4ca9d5c08d6ea02</OrderID><TxRefNum>605266890AF5BA833E6190D89256B892981C531D</TxRefNum><TxRefIdx>1</TxRefIdx><ProcStatus>0</ProcStatus><ApprovalStatus>1</ApprovalStatus><RespCode>00</RespCode><AVSRespCode>3</AVSRespCode><CVV2RespCode>M</CVV2RespCode><AuthCode>tst627</AuthCode><RecurringAdviceCd></RecurringAdviceCd><CAVVRespCode></CAVVRespCode><StatusMsg>Approved</StatusMsg><RespMsg></RespMsg><HostRespCode>100</HostRespCode><HostAVSRespCode></HostAVSRespCode><HostCVV2RespCode></HostCVV2RespCode><CustomerRefNum></CustomerRefNum><CustomerName></CustomerName><ProfileProcStatus></ProfileProcStatus><CustomerProfileMessage></CustomerProfileMessage><RespTime>162857</RespTime><PartialAuthOccurred></PartialAuthOccurred><RequestedAmount></RequestedAmount><RedeemedAmount></RedeemedAmount><RemainingBalance></RemainingBalance><CountryFraudFilterStatus></CountryFraudFilterStatus><IsoCountryCode></IsoCountryCode></NewOrderResp></Response>'
  end

  def pre_scrubbed
    <<~REQUEST
      opening connection to orbitalvar1.paymentech.net:443...
      opened
      starting SSL for orbitalvar1.paymentech.net:443...
      SSL established
      <- "POST /authorize HTTP/1.1\r\nContent-Type: application/PTI71\r\nMime-Version: 1.1\r\nContent-Transfer-Encoding: text\r\nRequest-Number: 1\r\nDocument-Type: Request\r\nInterface-Version: Ruby|ActiveMerchant|Proprietary Gateway\r\nContent-Length: 964\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: orbitalvar1.paymentech.net\r\n\r\n"
      <- "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<Request>\n  <NewOrder>\n    <OrbitalConnectionUsername>T16WAYSACT</OrbitalConnectionUsername>\n    <OrbitalConnectionPassword>zbp8X1ykGZ</OrbitalConnectionPassword>\n    <IndustryType>EC</IndustryType>\n    <MessageType>AC</MessageType>\n    <BIN>000001</BIN>\n    <MerchantID>041756</MerchantID>\n    <TerminalID>001</TerminalID>\n    <AccountNum>4112344112344113</AccountNum>\n    <Exp>0917</Exp>\n    <CurrencyCode>840</CurrencyCode>\n    <CurrencyExponent>2</CurrencyExponent>\n    <CardSecValInd>1</CardSecValInd>\n    <CardSecVal>123</CardSecVal>\n    <AVSzip>K1C2N6</AVSzip>\n    <AVSaddress1>456 My Street</AVSaddress1>\n    <AVSaddress2>Apt 1</AVSaddress2>\n    <AVScity>Ottawa</AVScity>\n    <AVSstate>ON</AVSstate>\n    <AVSphoneNum>5555555555</AVSphoneNum>\n    <AVSname>Longbob Longsen</AVSname>\n    <AVScountryCode>CA</AVScountryCode>\n    <OrderID>b141cf3ce2a442732e1906</OrderID>\n    <Amount>100</Amount>\n  </NewOrder>\n</Request>\n"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Date: Thu, 02 Jun 2016 07:04:44 GMT\r\n"
      -> "content-type: text/plain; charset=ISO-8859-1\r\n"
      -> "content-length: 1200\r\n"
      -> "content-transfer-encoding: text/xml\r\n"
      -> "document-type: Response\r\n"
      -> "mime-version: 1.0\r\n"
      -> "Connection: close\r\n"
      -> "\r\n"
      reading 1200 bytes...
      -> "<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><NewOrderResp><IndustryType></IndustryType><MessageType>AC</MessageType><MerchantID>041756</MerchantID><TerminalID>001</TerminalID><CardBrand>VI</CardBrand><AccountNum>4112344112344113</AccountNum><OrderID>b141cf3ce2a442732e1906</OrderID><TxRefNum>574FDA8CECFBC3DA073FF74A7E6DE4E0BA87545B</TxRefNum><TxRefIdx>2</TxRefIdx><ProcStatus>0</ProcStatus><ApprovalStatus>1</ApprovalStatus><RespCode>00</RespCode><AVSRespCode>7 </AVSRespCode><CVV2RespCode>M</CVV2RespCode><AuthCode>tst595</AuthCode><RecurringAdviceCd></RecurringAdviceCd><CAVVRespCode></CAVVRespCode><StatusMsg>Approved</StatusMsg><RespMsg></RespMsg><HostRespCode>100</HostRespCode><HostAVSRespCode>IU</HostAVSRespCode><HostCVV2RespCode>M</HostCVV2RespCode><CustomerRefNum></CustomerRefNum><CustomerName></CustomerName><ProfileProcStatus></ProfileProcStatus><CustomerProfileMessage></CustomerProfileMessage><RespTime>030444</RespTime><PartialAuthOccurred></PartialAuthOccurred><RequestedAmount></RequestedAmount><RedeemedAmount></RedeemedAmount><RemainingBalance></RemainingBalance><CountryFraudFilterStatus></CountryFraudFilterStatus><IsoCountryCode></IsoCountryCode></NewOrderResp></Response>"
      read 1200 bytes
      Conn close
    REQUEST
  end

  def post_scrubbed
    <<~REQUEST
      opening connection to orbitalvar1.paymentech.net:443...
      opened
      starting SSL for orbitalvar1.paymentech.net:443...
      SSL established
      <- "POST /authorize HTTP/1.1\r\nContent-Type: application/PTI71\r\nMime-Version: 1.1\r\nContent-Transfer-Encoding: text\r\nRequest-Number: 1\r\nDocument-Type: Request\r\nInterface-Version: Ruby|ActiveMerchant|Proprietary Gateway\r\nContent-Length: 964\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: orbitalvar1.paymentech.net\r\n\r\n"
      <- "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<Request>\n  <NewOrder>\n    <OrbitalConnectionUsername>[FILTERED]</OrbitalConnectionUsername>\n    <OrbitalConnectionPassword>[FILTERED]</OrbitalConnectionPassword>\n    <IndustryType>EC</IndustryType>\n    <MessageType>AC</MessageType>\n    <BIN>000001</BIN>\n    <MerchantID>[FILTERED]</MerchantID>\n    <TerminalID>001</TerminalID>\n    <AccountNum>[FILTERED]</AccountNum>\n    <Exp>0917</Exp>\n    <CurrencyCode>840</CurrencyCode>\n    <CurrencyExponent>2</CurrencyExponent>\n    <CardSecValInd>1</CardSecValInd>\n    <CardSecVal>[FILTERED]</CardSecVal>\n    <AVSzip>K1C2N6</AVSzip>\n    <AVSaddress1>456 My Street</AVSaddress1>\n    <AVSaddress2>Apt 1</AVSaddress2>\n    <AVScity>Ottawa</AVScity>\n    <AVSstate>ON</AVSstate>\n    <AVSphoneNum>5555555555</AVSphoneNum>\n    <AVSname>Longbob Longsen</AVSname>\n    <AVScountryCode>CA</AVScountryCode>\n    <OrderID>b141cf3ce2a442732e1906</OrderID>\n    <Amount>100</Amount>\n  </NewOrder>\n</Request>\n"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Date: Thu, 02 Jun 2016 07:04:44 GMT\r\n"
      -> "content-type: text/plain; charset=ISO-8859-1\r\n"
      -> "content-length: 1200\r\n"
      -> "content-transfer-encoding: text/xml\r\n"
      -> "document-type: Response\r\n"
      -> "mime-version: 1.0\r\n"
      -> "Connection: close\r\n"
      -> "\r\n"
      reading 1200 bytes...
      -> "<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><NewOrderResp><IndustryType></IndustryType><MessageType>AC</MessageType><MerchantID>[FILTERED]</MerchantID><TerminalID>001</TerminalID><CardBrand>VI</CardBrand><AccountNum>[FILTERED]</AccountNum><OrderID>b141cf3ce2a442732e1906</OrderID><TxRefNum>574FDA8CECFBC3DA073FF74A7E6DE4E0BA87545B</TxRefNum><TxRefIdx>2</TxRefIdx><ProcStatus>0</ProcStatus><ApprovalStatus>1</ApprovalStatus><RespCode>00</RespCode><AVSRespCode>7 </AVSRespCode><CVV2RespCode>M</CVV2RespCode><AuthCode>tst595</AuthCode><RecurringAdviceCd></RecurringAdviceCd><CAVVRespCode></CAVVRespCode><StatusMsg>Approved</StatusMsg><RespMsg></RespMsg><HostRespCode>100</HostRespCode><HostAVSRespCode>IU</HostAVSRespCode><HostCVV2RespCode>M</HostCVV2RespCode><CustomerRefNum></CustomerRefNum><CustomerName></CustomerName><ProfileProcStatus></ProfileProcStatus><CustomerProfileMessage></CustomerProfileMessage><RespTime>030444</RespTime><PartialAuthOccurred></PartialAuthOccurred><RequestedAmount></RequestedAmount><RedeemedAmount></RedeemedAmount><RemainingBalance></RemainingBalance><CountryFraudFilterStatus></CountryFraudFilterStatus><IsoCountryCode></IsoCountryCode></NewOrderResp></Response>"
      read 1200 bytes
      Conn close
    REQUEST
  end

  def pre_scrubbed_profile
    <<~REQUEST
      <?xml version="1.0" encoding="UTF-8"?><Response><ProfileResp><CustomerBin>000001</CustomerBin><CustomerMerchantID>253997</CustomerMerchantID><CustomerName>LONGBOB LONGSEN</CustomerName><CustomerRefNum>109273631</CustomerRefNum><CustomerProfileAction>CREATE</CustomerProfileAction><ProfileProcStatus>0</ProfileProcStatus><CustomerProfileMessage>Profile Request Processed</CustomerProfileMessage><CustomerAddress1>456 MY STREET</CustomerAddress1><CustomerAddress2>APT 1</CustomerAddress2><CustomerCity>OTTAWA</CustomerCity><CustomerState>ON</CustomerState><CustomerZIP>K1C2N6</CustomerZIP><CustomerEmail></CustomerEmail><CustomerPhone>5555555555</CustomerPhone><CustomerCountryCode>CA</CustomerCountryCode><CustomerProfileOrderOverrideInd>NO</CustomerProfileOrderOverrideInd><OrderDefaultDescription></OrderDefaultDescription><OrderDefaultAmount></OrderDefaultAmount><CustomerAccountType>CC</CustomerAccountType><Status>A</Status><CCAccountNum>4112344112344113</CCAccountNum><CCExpireDate>0919</CCExpireDate><ECPAccountDDA></ECPAccountDDA><ECPAccountType></ECPAccountType><ECPAccountRT></ECPAccountRT><ECPBankPmtDlv></ECPBankPmtDlv><SwitchSoloStartDate></SwitchSoloStartDate><SwitchSoloIssueNum></SwitchSoloIssueNum><RespTime></RespTime></ProfileResp></Response>
    REQUEST
  end

  def post_scrubbed_profile
    <<~REQUEST
      <?xml version="1.0" encoding="UTF-8"?><Response><ProfileResp><CustomerBin>000001</CustomerBin><CustomerMerchantID>[FILTERED]</CustomerMerchantID><CustomerName>LONGBOB LONGSEN</CustomerName><CustomerRefNum>109273631</CustomerRefNum><CustomerProfileAction>CREATE</CustomerProfileAction><ProfileProcStatus>0</ProfileProcStatus><CustomerProfileMessage>Profile Request Processed</CustomerProfileMessage><CustomerAddress1>456 MY STREET</CustomerAddress1><CustomerAddress2>APT 1</CustomerAddress2><CustomerCity>OTTAWA</CustomerCity><CustomerState>ON</CustomerState><CustomerZIP>K1C2N6</CustomerZIP><CustomerEmail></CustomerEmail><CustomerPhone>5555555555</CustomerPhone><CustomerCountryCode>CA</CustomerCountryCode><CustomerProfileOrderOverrideInd>NO</CustomerProfileOrderOverrideInd><OrderDefaultDescription></OrderDefaultDescription><OrderDefaultAmount></OrderDefaultAmount><CustomerAccountType>CC</CustomerAccountType><Status>A</Status><CCAccountNum>[FILTERED]</CCAccountNum><CCExpireDate>0919</CCExpireDate><ECPAccountDDA></ECPAccountDDA><ECPAccountType></ECPAccountType><ECPAccountRT></ECPAccountRT><ECPBankPmtDlv></ECPBankPmtDlv><SwitchSoloStartDate></SwitchSoloStartDate><SwitchSoloIssueNum></SwitchSoloIssueNum><RespTime></RespTime></ProfileResp></Response>
    REQUEST
  end
end
