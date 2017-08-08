require 'test_helper'

class GatewayTest < Test::Unit::TestCase
  def setup
    @gateway = Gateway.new
  end

  def teardown
    Gateway.money_format = :dollars
  end

  def test_should_detect_if_a_card_is_supported
    Gateway.supported_cardtypes = [:visa, :bogus]
    assert [:visa, :bogus].all? { |supported_cardtype| Gateway.supports?(supported_cardtype) }

    Gateway.supported_cardtypes = []
    assert_false [:visa, :bogus].all? { |invalid_cardtype| Gateway.supports?(invalid_cardtype) }
  end

  def test_should_validate_supported_countries
    assert_raise(ActiveMerchant::InvalidCountryCodeError) do
      Gateway.supported_countries = %w(us uk sg)
    end

    all_country_codes = ActiveMerchant::Country::COUNTRIES.collect do |country|
      [country[:alpha2], country[:alpha3]]
    end.flatten

    assert_nothing_raised do
      Gateway.supported_countries = all_country_codes
      assert Gateway.supported_countries == all_country_codes,
        "List of supported countries not properly set"
    end
  end

  def test_should_gateway_uses_ssl_strict_checking_by_default
    assert Gateway.ssl_strict
  end

  def test_should_be_able_to_look_for_test_mode
    Base.mode = :test
    assert @gateway.test?

    Base.mode = :production
    assert_false @gateway.test?
  end

  def test_amount_style
   assert_equal '10.34', @gateway.send(:amount, 1034)

   assert_raise(ArgumentError) do
     @gateway.send(:amount, '10.34')
   end
  end

  def test_card_brand
    credit_card = stub(:brand => "visa")
    assert_equal "visa", Gateway.card_brand(credit_card)
  end

  def test_card_brand_using_type
    credit_card = stub(:type => "String")
    assert_equal "string", Gateway.card_brand(credit_card)
  end

  def test_setting_application_id_outside_the_class_definition
    assert_equal SimpleTestGateway.application_id, SubclassGateway.application_id
    SimpleTestGateway.application_id = "New Application ID"

    assert_equal SimpleTestGateway.application_id, SubclassGateway.application_id
  end

  def test_localized_amount_should_not_modify_for_fractional_currencies
    Gateway.money_format = :dollars
    assert_equal '1.00', @gateway.send(:localized_amount, 100, 'CAD')
    assert_equal '12.34', @gateway.send(:localized_amount, 1234, 'USD')

    Gateway.money_format = :cents
    assert_equal '100', @gateway.send(:localized_amount, 100, 'CAD')
    assert_equal '1234', @gateway.send(:localized_amount, 1234, 'USD')
  end

  def test_localized_amount_should_ignore_money_format_for_non_fractional_currencies
    Gateway.money_format = :dollars
    assert_equal '1', @gateway.send(:localized_amount, 100, 'JPY')
    assert_equal '12', @gateway.send(:localized_amount, 1234, 'ISK')

    Gateway.money_format = :cents
    assert_equal '1', @gateway.send(:localized_amount, 100, 'JPY')
    assert_equal '12', @gateway.send(:localized_amount, 1234, 'ISK')
  end

  def test_localized_amount_returns_three_decimal_places_for_three_decimal_currencies
    @gateway.currencies_with_three_decimal_places = %w(BHD KWD OMR RSD TND)

    Gateway.money_format = :dollars
    assert_equal '0.100', @gateway.send(:localized_amount, 100, 'OMR')
    assert_equal '1.234', @gateway.send(:localized_amount, 1234, 'BHD')

    Gateway.money_format = :cents
    assert_equal '100', @gateway.send(:localized_amount, 100, 'OMR')
    assert_equal '1234', @gateway.send(:localized_amount, 1234, 'BHD')
  end

  def test_split_names
    assert_equal ["Longbob", "Longsen"], @gateway.send(:split_names, "Longbob Longsen")
  end

  def test_split_names_with_single_name
    assert_equal ["", "Prince"], @gateway.send(:split_names, "Prince")
  end

  def test_split_names_with_empty_names
    assert_equal [nil, nil], @gateway.send(:split_names, "")
    assert_equal [nil, nil], @gateway.send(:split_names, nil)
    assert_equal [nil, nil], @gateway.send(:split_names, " ")
  end


  def test_supports_scrubbing?
    gateway = Gateway.new
    refute gateway.supports_scrubbing?
  end

  def test_should_not_allow_scrubbing_if_unsupported
    gateway = Gateway.new
    refute gateway.supports_scrubbing?

    assert_raise(RuntimeError) do
      gateway.scrub("hi")
    end
  end

  def test_strip_invalid_xml_chars
    xml = <<EOF
      <response>
        <element>Parse the First & but not this &tilde; &x002a;</element>
      </response>
EOF
    parsed_xml = @gateway.send(:strip_invalid_xml_chars, xml)

    assert REXML::Document.new(parsed_xml)
    assert_raise(REXML::ParseException) do
      REXML::Document.new(xml)
    end
  end
end
