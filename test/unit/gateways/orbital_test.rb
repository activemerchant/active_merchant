# encoding: utf-8

require 'test_helper'
require 'nokogiri'

class OrbitalGatewayTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = ActiveMerchant::Billing::OrbitalGateway.new(
      :login => 'login',
      :password => 'password',
      :merchant_id => 'merchant_id'
    )
    @customer_ref_num = "ABC"

    @level_2 = {
      tax_indicator: 1,
      tax: 10,
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
      zip: address[:zip],
    }

    @options = { :order_id => '1'}
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.purchase(50, credit_card, :order_id => '1')
    assert_instance_of Response, response
    assert_success response
    assert_equal '4A5398CF9B87744GG84A1D30F2F2321C66249416;1', response.authorization
  end

  def test_level_2_data
    stub_comms do
      @gateway.purchase(50, credit_card, @options.merge(level_2_data: @level_2))
    end.check_request do |endpoint, data, headers|
      assert_match %{<TaxInd>#{@level_2[:tax_indicator]}</TaxInd>}, data
      assert_match %{<Tax>#{@level_2[:tax]}</Tax>}, data
      assert_match %{<AMEXTranAdvAddn1>#{@level_2[:advice_addendum_1]}</AMEXTranAdvAddn1>}, data
      assert_match %{<AMEXTranAdvAddn2>#{@level_2[:advice_addendum_2]}</AMEXTranAdvAddn2>}, data
      assert_match %{<AMEXTranAdvAddn3>#{@level_2[:advice_addendum_3]}</AMEXTranAdvAddn3>}, data
      assert_match %{<AMEXTranAdvAddn4>#{@level_2[:advice_addendum_4]}</AMEXTranAdvAddn4>}, data
      assert_match %{<PCOrderNum>#{@level_2[:purchase_order]}</PCOrderNum>}, data
      assert_match %{<PCDestZip>#{@level_2[:zip]}</PCDestZip>}, data
      assert_match %{<PCDestName>#{@level_2[:name]}</PCDestName>}, data
      assert_match %{<PCDestAddress1>#{@level_2[:address1]}</PCDestAddress1>}, data
      assert_match %{<PCDestAddress2>#{@level_2[:address2]}</PCDestAddress2>}, data
      assert_match %{<PCDestCity>#{@level_2[:city]}</PCDestCity>}, data
      assert_match %{<PCDestState>#{@level_2[:state]}</PCDestState>}, data
    end.respond_with(successful_purchase_response)
  end

  def test_network_tokenization_credit_card_data
    stub_comms do
      @gateway.purchase(50, network_tokenization_credit_card(nil, eci: '5', transaction_id: 'BwABB4JRdgAAAAAAiFF2AAAAAAA='), @options)
    end.check_request do |endpoint, data, headers|
      assert_match %{<AuthenticationECIInd>5</AuthenticationECIInd>}, data
      assert_match %{<DPANInd>Y</DPANInd>}, data
      assert_match %{DigitalTokenCryptogram}, data
      assert_match %{XID}, data
    end.respond_with(successful_purchase_response)
  end

  def test_currency_exponents
    stub_comms do
      @gateway.purchase(50, credit_card, :order_id => '1')
    end.check_request do |endpoint, data, headers|
      assert_match %r{<CurrencyExponent>2<\/CurrencyExponent>}, data
    end.respond_with(successful_purchase_response)

    stub_comms do
      @gateway.purchase(50, credit_card, :order_id => '1', :currency => 'CAD')
    end.check_request do |endpoint, data, headers|
      assert_match %r{<CurrencyExponent>2<\/CurrencyExponent>}, data
    end.respond_with(successful_purchase_response)

    stub_comms do
      @gateway.purchase(50, credit_card, :order_id => '1', :currency => 'JPY')
    end.check_request do |endpoint, data, headers|
      assert_match %r{<CurrencyExponent>0<\/CurrencyExponent>}, data
    end.respond_with(successful_purchase_response)
  end

  def test_unauthenticated_response
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    assert response = @gateway.purchase(101, credit_card, :order_id => '1')
    assert_instance_of Response, response
    assert_failure response
    assert_equal "AUTH DECLINED                   12001", response.message
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)

    assert response = @gateway.void("identifier")
    assert_instance_of Response, response
    assert_success response
    assert_nil response.message
  end

  def test_deprecated_void
    @gateway.expects(:ssl_post).returns(successful_void_response)

    assert_deprecation_warning("Calling the void method with an amount parameter is deprecated and will be removed in a future version.") do
      assert response = @gateway.void(50, "identifier")
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
      @gateway.purchase(101, credit_card, :order_id => 1)
    end
  end

  def test_order_id_format
    response = stub_comms do
      @gateway.purchase(101, credit_card, :order_id => " #101.23,56 $Hi &thére@Friends")
    end.check_request do |endpoint, data, headers|
      assert_match(/<OrderID>101-23,56 \$Hi &amp;thre@Fr<\/OrderID>/, data)
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_order_id_format_for_capture
    response = stub_comms do
      @gateway.capture(101, "4A5398CF9B87744GG84A1D30F2F2321C66249416;1001.1", :order_id => "#1001.1")
    end.check_request do |endpoint, data, headers|
      assert_match(/<OrderID>1001-1<\/OrderID>/, data)
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_expiry_date
    year = (DateTime.now + 1.year).strftime("%y")
    assert_equal "09#{year}", @gateway.send(:expiry_date, credit_card)
  end

  def test_phone_number
    response = stub_comms do
      @gateway.purchase(50, credit_card, :order_id => 1, :billing_address => address(:phone => '123-456-7890'))
    end.check_request do |endpoint, data, headers|
      assert_match(/1234567890/, data)
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_truncates_address
    long_address = '1850 Treebeard Drive in Fangorn Forest by the Fields of Rohan'

    response = stub_comms do
      @gateway.purchase(50, credit_card, :order_id => 1, :billing_address => address(:address1 => long_address))
    end.check_request do |endpoint, data, headers|
      assert_match(/1850 Treebeard Drive/, data)
      assert_no_match(/Fields of Rohan/, data)
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_truncates_name
    card = credit_card('4242424242424242',
                       :first_name => 'John',
                       :last_name => 'Jacob Jingleheimer Smith-Jones')

    response = stub_comms do
      @gateway.purchase(50, card, :order_id => 1, :billing_address => address)
    end.check_request do |endpoint, data, headers|
      assert_match(/John Jacob/, data)
      assert_no_match(/Jones/, data)
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_truncates_city
    long_city = 'Friendly Village of Crooked Creek'

    response = stub_comms do
      @gateway.purchase(50, credit_card, :order_id => 1, :billing_address => address(:city => long_city))
    end.check_request do |endpoint, data, headers|
      assert_match(/Friendly Village/, data)
      assert_no_match(/Creek/, data)
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_truncates_phone
    long_phone = '123456789012345'

    response = stub_comms do
      @gateway.purchase(50, credit_card, :order_id => 1, :billing_address => address(:phone => long_phone))
    end.check_request do |endpoint, data, headers|
      assert_match(/12345678901234</, data)
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_truncates_zip
   long_zip = '1234567890123'

    response = stub_comms do
      @gateway.purchase(50, credit_card, :order_id => 1, :billing_address => address(:zip => long_zip))
    end.check_request do |endpoint, data, headers|
      assert_match(/1234567890</, data)
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_address_format
    address_with_invalid_chars = address(
      :address1 =>      '456% M|a^in \\S/treet',
      :address2 =>      '|Apt. ^Num\\ber /One%',
      :city =>          'R^ise o\\f /th%e P|hoenix',
      :state =>         '%O|H\\I/O',
      :dest_address1 => '2/21%B |B^aker\\ St.',
      :dest_address2 => 'L%u%xury S|u^i\\t/e',
      :dest_city =>     '/Winn/i%p|e^g\\',
      :dest_zip =>      'A1A 2B2',
      :dest_state =>    '^MB',
    )

    response = stub_comms do
      @gateway.purchase(50, credit_card, :order_id => 1,
        :billing_address => address_with_invalid_chars)
    end.check_request do |endpoint, data, headers|
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
          :billing_address => address_with_invalid_chars)
      end
    end.check_request do |endpoint, data, headers|
      assert_match(/456 Main Street</, data)
      assert_match(/Apt. Number One</, data)
      assert_match(/Rise of the Phoenix</, data)
    end.respond_with(successful_profile_response)
    assert_success response
  end

  def test_truncates_by_byte_length
    card = credit_card('4242424242424242',
                       :first_name => 'John',
                       :last_name => 'Jacob Jingleheimer Smith-Jones')

    long_address = address(
      :address1 =>      '456 Stréêt Name is Really Long',
      :address2 =>      'Apårtmeñt 123456789012345678901',
      :city =>          '¡Vancouver-by-the-sea!',
      :state =>         'ßC',
      :zip =>           'Postäl Cøde',
      :dest_name =>     'Pierré von Bürgermeister de Queso',
      :dest_address1 => '9876 Stréêt Name is Really Long',
      :dest_address2 => 'Apårtmeñt 987654321098765432109',
      :dest_city =>     'Montréal-of-the-south!',
      :dest_state =>    'Oñtario',
      :dest_zip =>      'Postäl Zïps'
    )

    response = stub_comms do
      @gateway.purchase(50, card, :order_id => 1,
        :billing_address => long_address)
    end.check_request do |endpoint, data, headers|
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
          :billing_address => long_address)
      end
    end.check_request do |endpoint, data, headers|
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
      :address1 => nil,
      :address2 => nil,
      :city     => nil,
      :state    => nil,
      :zip      => nil,
      :email    => nil,
      :phone    => nil,
      :fax      => nil
    }

    response = @gateway.purchase(50, credit_card, :order_id => 1, :billing_address => address(address_options))
    assert_success response
  end

  def test_dest_address
    billing_address = address(
      :dest_zip      => '90001',
      :dest_address1 => '456 Main St.',
      :dest_city     => 'Somewhere',
      :dest_state    => 'CA',
      :dest_name     => 'Joan Smith',
      :dest_phone    => '(123) 456-7890',
      :dest_country  => 'US')

    response = stub_comms do
      @gateway.purchase(50, credit_card, :order_id => 1,
        :billing_address => billing_address)
    end.check_request do |endpoint, data, headers|
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
      @gateway.purchase(50, credit_card, :order_id => 1,
        :billing_address => billing_address.merge(:dest_country => 'BR'))
    end.check_request do |endpoint, data, headers|
      assert_match(/<AVSDestcountryCode></, data)
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_default_managed_billing
    response = stub_comms do
      assert_deprecation_warning(Gateway::RECURRING_DEPRECATION_MESSAGE) do
        assert_deprecation_warning do
          @gateway.add_customer_profile(credit_card, :managed_billing => {:start_date => "10-10-2014" })
        end
      end
    end.check_request do |endpoint, data, headers|
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
          @gateway.add_customer_profile(credit_card, :managed_billing => {:start_date => "10-10-2014",
                  :end_date => "10-10-2015",
                  :max_dollar_value => 1500,
                  :max_transactions => 12})
        end
      end
    end.check_request do |endpoint, data, headers|
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
      @gateway.purchase(50, credit_card, :order_id => 1)
    end.check_request do |endpoint, data, headers|
      assert_no_match(/<CustomerRefNum>K1C2N6/, data)
      assert_no_match(/<CustomerProfileFromOrderInd>456 My Street/, data)
      assert_no_match(/<CustomerProfileOrderOverrideInd>Apt 1/, data)
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_send_customer_data_when_customer_profiles_is_enabled
    @gateway.options[:customer_profiles] = true
    response = stub_comms do
      @gateway.purchase(50, credit_card, :order_id => 1)
    end.check_request do |endpoint, data, headers|
      assert_match(/<CustomerProfileFromOrderInd>A/, data)
      assert_match(/<CustomerProfileOrderOverrideInd>NO/, data)
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_send_customer_data_when_customer_ref_is_provided
    @gateway.options[:customer_profiles] = true
    response = stub_comms do
      @gateway.purchase(50, credit_card, :order_id => 1, :customer_ref_num => @customer_ref_num)
    end.check_request do |endpoint, data, headers|
      assert_match(/<CustomerRefNum>ABC/, data)
      assert_match(/<CustomerProfileFromOrderInd>S/, data)
      assert_match(/<CustomerProfileOrderOverrideInd>NO/, data)
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_dont_send_customer_profile_from_order_ind_for_profile_purchase
    @gateway.options[:customer_profiles] = true
    response = stub_comms do
      @gateway.purchase(50, nil, :order_id => 1, :customer_ref_num => @customer_ref_num)
    end.check_request do |endpoint, data, headers|
      assert_no_match(/<CustomerProfileFromOrderInd>/, data)
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_dont_send_customer_profile_from_order_ind_for_profile_authorize
    @gateway.options[:customer_profiles] = true
    response = stub_comms do
      @gateway.authorize(50, nil, :order_id => 1, :customer_ref_num => @customer_ref_num)
    end.check_request do |endpoint, data, headers|
      assert_no_match(/<CustomerProfileFromOrderInd>/, data)
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_currency_code_and_exponent_are_set_for_profile_purchase
    @gateway.options[:customer_profiles] = true
    response = stub_comms do
      @gateway.purchase(50, nil, :order_id => 1, :customer_ref_num => @customer_ref_num)
    end.check_request do |endpoint, data, headers|
      assert_match(/<CustomerRefNum>ABC/, data)
      assert_match(/<CurrencyCode>124/, data)
      assert_match(/<CurrencyExponent>2/, data)
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_currency_code_and_exponent_are_set_for_profile_authorizations
    @gateway.options[:customer_profiles] = true
    response = stub_comms do
      @gateway.authorize(50, nil, :order_id => 1, :customer_ref_num => @customer_ref_num)
    end.check_request do |endpoint, data, headers|
      assert_match(/<CustomerRefNum>ABC/, data)
      assert_match(/<CurrencyCode>124/, data)
      assert_match(/<CurrencyExponent>2/, data)
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  #   <AVSzip>K1C2N6</AVSzip>
  #   <AVSaddress1>456 My Street</AVSaddress1>
  #   <AVSaddress2>Apt 1</AVSaddress2>
  #   <AVScity>Ottawa</AVScity>
  #   <AVSstate>ON</AVSstate>
  #   <AVSphoneNum>5555555555</AVSphoneNum>
  #   <AVSname>Longbob Longsen</AVSname>
  #   <AVScountryCode>CA</AVScountryCode>
  def test_send_address_details_for_united_states
    response = stub_comms do
      @gateway.purchase(50, credit_card, :order_id => 1, :billing_address => address)
    end.check_request do |endpoint, data, headers|
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
      @gateway.purchase(50, credit_card, :order_id => 1, :billing_address => address(:country => 'DE'))
    end.check_request do |endpoint, data, headers|
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
      @gateway.purchase(50, credit_card, :order_id => 1, :billing_address => address(:country => nil))
    end.check_request do |endpoint, data, headers|
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
      @gateway.purchase(50, credit_card, :order_id => 1, :billing_address => address)
    end.check_request do |endpoint, data, headers|
      schema_file = File.read("#{File.dirname(__FILE__)}/../../schema/orbital/Request_PTI54.xsd")
      doc = Nokogiri::XML(data)
      xsd = Nokogiri::XML::Schema(schema_file)
      assert xsd.valid?(doc), "Request does not adhere to DTD"
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_german_requests_adhere_to_xml_schema
    response = stub_comms do
      @gateway.purchase(50, credit_card, :order_id => 1, :billing_address => address(:country => 'DE'))
    end.check_request do |endpoint, data, headers|
      schema_file = File.read("#{File.dirname(__FILE__)}/../../schema/orbital/Request_PTI54.xsd")
      doc = Nokogiri::XML(data)
      xsd = Nokogiri::XML::Schema(schema_file)
      assert xsd.valid?(doc), "Request does not adhere to DTD"
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_add_customer_profile
    response = stub_comms do
      assert_deprecation_warning do
        @gateway.add_customer_profile(credit_card)
      end
    end.check_request do |endpoint, data, headers|
      assert_match(/<CustomerProfileAction>C/, data)
      assert_match(/<CustomerName>Longbob Longsen/, data)
    end.respond_with(successful_profile_response)
    assert_success response
  end

  def test_add_customer_profile_with_email
    response = stub_comms do
      assert_deprecation_warning do
        @gateway.add_customer_profile(credit_card, { :billing_address => { :email => 'xiaobozzz@example.com' } })
      end
    end.check_request do |endpoint, data, headers|
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
    end.check_request do |endpoint, data, headers|
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
    end.check_request do |endpoint, data, headers|
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
    end.check_request do |endpoint, data, headers|
      assert_no_match(/<CustomerName>Longbob Longsen/, data)
      assert_match(/<CustomerProfileAction>D/, data)
      assert_match(/<CustomerRefNum>ABC/, data)
    end.respond_with(successful_profile_response)
    assert_success response
  end

  def test_attempts_seconday_url
    @gateway.expects(:ssl_post).with(OrbitalGateway.test_url, anything, anything).raises(ActiveMerchant::ConnectionError.new("message", nil))
    @gateway.expects(:ssl_post).with(OrbitalGateway.secondary_test_url, anything, anything).returns(successful_purchase_response)

    response = @gateway.purchase(50, credit_card, :order_id => '1')
    assert_success response
  end

  # retry_logic true and some value for trace_number.
  def test_headers_when_retry_logic_is_enabled
    @gateway.options[:retry_logic] = true
    response = stub_comms do
      @gateway.purchase(50, credit_card, :order_id => 1, :trace_number => 1)
    end.check_request do |endpoint, data, headers|
      assert_equal('1', headers['Trace-number'])
      assert_equal('merchant_id', headers['Merchant-Id'])
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_retry_logic_not_enabled
    @gateway.options[:retry_logic] = false
    response = stub_comms do
      @gateway.purchase(50, credit_card, :order_id => 1, :trace_number => 1)
    end.check_request do |endpoint, data, headers|
      assert_equal(false, headers.has_key?('Trace-number'))
      assert_equal(false, headers.has_key?('Merchant-Id'))
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  ActiveMerchant::Billing::OrbitalGateway::APPROVED.each do |resp_code|
    define_method "test_approval_response_code_#{resp_code}" do
      @gateway.expects(:ssl_post).returns(successful_purchase_response(resp_code))

      assert response = @gateway.purchase(50, credit_card, :order_id => '1')
      assert_instance_of Response, response
      assert_success response
    end
  end

  def test_account_num_is_removed_from_response
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(50, credit_card, :order_id => '1')
    assert_instance_of Response, response
    assert_success response
    assert_nil response.params['account_num']
  end

  def test_cc_account_num_is_removed_from_response
    @gateway.expects(:ssl_post).returns(successful_profile_response)

    response = nil

    assert_deprecation_warning do
      response = @gateway.add_customer_profile(credit_card,
          :billing_address => address)
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
    assert_equal "Approved", response.message
  end

  def test_successful_verify_and_failed_void
    response = stub_comms do
      @gateway.verify(credit_card, @options)
    end.respond_with(successful_purchase_response, failed_purchase_response)
    assert_success response
    assert_equal '4A5398CF9B87744GG84A1D30F2F2321C66249416;1', response.authorization
    assert_equal "Approved", response.message
  end

  def test_failed_verify
    response = stub_comms do
      @gateway.verify(credit_card, @options)
    end.respond_with(failed_purchase_response, failed_purchase_response)
    assert_failure response
    assert_equal "AUTH DECLINED                   12001", response.message
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
      @gateway.purchase(50, credit_card(nil, {verification_value: nil}), @options)
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

  def successful_purchase_response(resp_code = '00')
    %Q{<?xml version="1.0" encoding="UTF-8"?><Response><NewOrderResp><IndustryType></IndustryType><MessageType>AC</MessageType><MerchantID>700000000000</MerchantID><TerminalID>001</TerminalID><CardBrand>VI</CardBrand><AccountNum>4111111111111111</AccountNum><OrderID>1</OrderID><TxRefNum>4A5398CF9B87744GG84A1D30F2F2321C66249416</TxRefNum><TxRefIdx>1</TxRefIdx><ProcStatus>0</ProcStatus><ApprovalStatus>1</ApprovalStatus><RespCode>#{resp_code}</RespCode><AVSRespCode>H </AVSRespCode><CVV2RespCode>N</CVV2RespCode><AuthCode>091922</AuthCode><RecurringAdviceCd></RecurringAdviceCd><CAVVRespCode></CAVVRespCode><StatusMsg>Approved</StatusMsg><RespMsg></RespMsg><HostRespCode>00</HostRespCode><HostAVSRespCode>Y</HostAVSRespCode><HostCVV2RespCode>N</HostCVV2RespCode><CustomerRefNum></CustomerRefNum><CustomerName></CustomerName><ProfileProcStatus></ProfileProcStatus><CustomerProfileMessage></CustomerProfileMessage><RespTime>144951</RespTime></NewOrderResp></Response>}
  end

  def failed_purchase_response
    %q{<?xml version="1.0" encoding="UTF-8"?><Response><NewOrderResp><IndustryType></IndustryType><MessageType>AC</MessageType><MerchantID>700000000000</MerchantID><TerminalID>001</TerminalID><CardBrand>VI</CardBrand><AccountNum>4000300011112220</AccountNum><OrderID>1</OrderID><TxRefNum>4A5398CF9B87744GG84A1D30F2F2321C66249416</TxRefNum><TxRefIdx>0</TxRefIdx><ProcStatus>0</ProcStatus><ApprovalStatus>0</ApprovalStatus><RespCode>05</RespCode><AVSRespCode>G </AVSRespCode><CVV2RespCode>N</CVV2RespCode><AuthCode></AuthCode><RecurringAdviceCd></RecurringAdviceCd><CAVVRespCode></CAVVRespCode><StatusMsg>Do Not Honor</StatusMsg><RespMsg>AUTH DECLINED                   12001</RespMsg><HostRespCode>05</HostRespCode><HostAVSRespCode>N</HostAVSRespCode><HostCVV2RespCode>N</HostCVV2RespCode><CustomerRefNum></CustomerRefNum><CustomerName></CustomerName><ProfileProcStatus></ProfileProcStatus><CustomerProfileMessage></CustomerProfileMessage><RespTime>150214</RespTime></NewOrderResp></Response>}
  end

  def successful_profile_response
    %q{<?xml version="1.0" encoding="UTF-8"?><Response><ProfileResp><CustomerBin>000001</CustomerBin><CustomerMerchantID>700000000000</CustomerMerchantID><CustomerName>Longbob Longsen</CustomerName><CustomerRefNum>ABC</CustomerRefNum><CustomerProfileAction>CREATE</CustomerProfileAction><ProfileProcStatus>0</ProfileProcStatus><CustomerProfileMessage>Profile Request Processed</CustomerProfileMessage><CustomerAccountType>CC</CustomerAccountType><Status>A</Status><CCAccountNum>4111111111111111</CCAccountNum><RespTime/></ProfileResp></Response>}
  end

  def successful_void_response
    %q{<?xml version="1.0" encoding="UTF-8"?><Response><ReversalResp><MerchantID>700000208761</MerchantID><TerminalID>001</TerminalID><OrderID>2</OrderID><TxRefNum>50FB1C41FEC9D016FF0BEBAD0884B174AD0853B0</TxRefNum><TxRefIdx>1</TxRefIdx><OutstandingAmt>0</OutstandingAmt><ProcStatus>0</ProcStatus><StatusMsg></StatusMsg><RespTime>01192013172049</RespTime></ReversalResp></Response>}
  end

  def pre_scrubbed
    <<-EOS
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
    EOS
  end

  def post_scrubbed
    <<-EOS
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
    EOS
  end
end
