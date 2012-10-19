require 'test_helper'

class HdfcTest < Test::Unit::TestCase
  include CommStub

  def setup
    Base.mode = :test

    @gateway = HdfcGateway.new(
      :login => 'login',
      :password => 'password'
    )

    @credit_card = credit_card
    @amount = 100
  end

  def test_successful_purchase
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(successful_purchase_response)

    assert_success response

    assert_equal "849768440022761|Longbob Longsen", response.authorization
    assert response.test?
  end

  def test_failed_purchase
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(failed_purchase_response)

    assert_failure response
    assert_equal "Invalid Brand.", response.message
    assert_equal "GW00160", response.params["error_code_tag"]
    assert response.test?
  end

  def test_authorize_and_capture
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card)
    end.respond_with(successful_authorize_response)

    assert_success response
    assert_equal "2441955352022771|Longbob Longsen", response.authorization

    capture = stub_comms do
      @gateway.capture(@amount, response.authorization)
    end.check_request do |endpoint, data, headers|
      assert_match(/2441955352022771/, data)
    end.respond_with(successful_capture_response)

    assert_success capture
  end

  def test_refund
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(successful_purchase_response)

    assert_success response
    assert_equal "849768440022761|Longbob Longsen", response.authorization

    refund = stub_comms do
      @gateway.refund(@amount, response.authorization)
    end.check_request do |endpoint, data, headers|
      assert_match(/849768440022761/, data)
    end.respond_with(successful_refund_response)

    assert_success refund
  end

  def test_passing_cvv
    stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.check_request do |endpoint, data, headers|
      assert_match(/#{@credit_card.verification_value}/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_passing_currency
    stub_comms do
      @gateway.purchase(@amount, @credit_card, :currency => "INR")
    end.check_request do |endpoint, data, headers|
      assert_match(/currencycode>356</, data)
    end.respond_with(successful_purchase_response)
  end

  def test_passing_invalid_currency
    assert_raise(ArgumentError, %r(unsupported currency)i) do
      @gateway.purchase(@amount, @credit_card, :currency => "AOA")
    end
  end

  def test_passing_order_id
    stub_comms do
      @gateway.purchase(@amount, @credit_card, :order_id => "932823723")
    end.check_request do |endpoint, data, headers|
      assert_match(/932823723/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_passing_description
    stub_comms do
      @gateway.purchase(@amount, @credit_card, :description => "Awesome Services By Us")
    end.check_request do |endpoint, data, headers|
      assert_match(/Awesome Services By Us/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_escaping
    stub_comms do
      @gateway.purchase(@amount, @credit_card, :order_id => "a" * 41, :description => "This has 'Hack Characters' ~`!\#$%^=+|\\:'\",;<>{}[]() and non-Hack Characters -_@.")
    end.check_request do |endpoint, data, headers|
      assert_match(/>This has Hack Characters  and non-Hack Characters -_@.</, data)
      assert_match(/>#{"a" * 40}</, data)
    end.respond_with(successful_purchase_response)
  end

  def test_passing_billing_address
    stub_comms do
      @gateway.purchase(@amount, @credit_card, :billing_address => address)
    end.check_request do |endpoint, data, headers|
      assert_match(/udf4>Jim Smith\nWidgets Inc\n1234 My Street\nApt 1\nOttawa ON K1C2N6\nCA/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_passing_phone_number
    stub_comms do
      @gateway.purchase(@amount, @credit_card, :billing_address => address)
    end.check_request do |endpoint, data, headers|
      assert_match(/udf3>555555-5555</, data)
    end.respond_with(successful_purchase_response)
  end

  def test_passing_billing_address_without_phone
    stub_comms do
      @gateway.purchase(@amount, @credit_card, :billing_address => address(:phone => nil))
    end.check_request do |endpoint, data, headers|
      assert_no_match(/udf3/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_passing_eci
    stub_comms do
      @gateway.purchase(@amount, @credit_card, :eci => 22)
    end.check_request do |endpoint, data, headers|
      assert_match(/eci>22</, data)
    end.respond_with(successful_purchase_response)
  end

  def test_empty_response_fails
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(empty_purchase_response)

    assert_failure response
    assert_equal "Unable to read error message", response.message
  end

  private

  def successful_purchase_response
    %(
      <result>CAPTURED</result>
      <auth>999999</auth>
      <ref>227615274218</ref>
      <avr>N</avr>
      <postdate>1002</postdate>
      <tranid>849768440022761</tranid>
      <payid>-1</payid>
      <udf2></udf2>
      <udf5></udf5>
      <amt>1.00</amt>
    )
  end

  def successful_authorize_response
    %(
      <result>APPROVED</result>
      <auth>999999</auth>
      <ref>227721068433</ref>
      <avr>N</avr>
      <postdate>1004</postdate>
      <tranid>2441955352022771</tranid>
      <trackid>49c89e3b84f7563e62d1109dab0379fd</trackid>
      <payid>-1</payid>
      <udf1>Store Purchase</udf1>
      <udf2></udf2>
      <udf5></udf5>
      <amt>1.00</amt>
    )
  end

  # Use the authorize response until we can get the remote reference tests
  # working
  alias successful_capture_response successful_authorize_response
  alias successful_refund_response successful_authorize_response

  def failed_purchase_response
    %(
      <error_code_tag>GW00160</error_code_tag>
      <error_service_tag>null</error_service_tag>
      <result>!ERROR!-GW00160-Invalid Brand.</result>
    )
  end

  def empty_purchase_response
    %(
    )
  end
end
