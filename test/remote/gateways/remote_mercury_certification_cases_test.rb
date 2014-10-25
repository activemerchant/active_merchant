require 'test_helper'
require "support/mercury_helper"

class RemoteMercuryCertificationTest < Test::Unit::TestCase
  include MercuryHelper

  def setup
    @gateway = MercuryGateway.new(fixtures(:mercury))

    @amount = 100

    @credit_card = credit_card("4003000123456781", :brand => "visa", :month => "12", :year => "15")

    @credit_card_track_data = credit_card_track_data("4005550000000480")

    @options = {
      :order_id => "1",
      :description => "ActiveMerchant"
    }
    @options_with_billing = @options.merge(
      :merchant => '999',
      :billing_address => {
        :address1 => '4 Corporate SQ',
        :zip => '30329'
      }
    )
    @full_options = @options_with_billing.merge(
      :ip => '123.123.123.123',
      :merchant => "Open Dining",
      :customer => "Tim",
      :tax => "5"
    )

  end

  def test_11
    @gateway = MercuryGateway.new(:login => "003503902913105", :password => "xyz")
    response = @gateway.purchase(101, @credit_card_track_data, @options)
    assert_success response
    assert_equal "1.01", response.params["purchase"]
  end
  def test_12
    @gateway = MercuryGateway.new(:login => "118725340908147", :password => "xyz")
    response = @gateway.purchase(102, @credit_card_track_data, @options)
    assert_success response
    assert_equal "1.02", response.params["purchase"]
  end
  def test_13
    @gateway = MercuryGateway.new(:login => "023358150511666", :password => "xyz")
    response = @gateway.purchase(103, @credit_card_track_data, @options)
    assert_success response
    assert_equal "1.03", response.params["purchase"]
  end

  def test_21
    @credit_card_track_data = credit_card_track_data("373953244361001")
    response = @gateway.authorize(104, @credit_card_track_data, @options)
    assert_success response
    assert_equal '1.04', response.params['authorize']
  end

  def test_22
    @credit_card_track_data = credit_card_track_data("6011900212345677")
    response = @gateway.authorize(105, @credit_card_track_data, @options)
    assert_success response
    assert_equal '1.05', response.params['authorize']
  end

  def test_23
    @credit_card_track_data = credit_card_track_data("5439750001500248")
    response = @gateway.purchase(106, @credit_card_track_data, @options)
    assert_success response
    assert_equal "1.06", response.params["purchase"]
  end

  def test_24
    @credit_card_track_data = credit_card_track_data("4005550000000480")
    response = @gateway.purchase(107, @credit_card_track_data, @options)
    assert_success response
    assert_equal "1.07", response.params["purchase"]
  end

  def test_31
    response = @gateway.authorize(107, @credit_card_track_data, @options)
    assert_success response
    assert_equal '1.07', response.params['authorize']
  end

  def test_32
    response = @gateway.authorize(107, @credit_card_track_data, @options)
    assert_success response
    assert_equal '1.07', response.params['authorize']
  end

  def test_33
    response = @gateway.purchase(107, @credit_card_track_data, @options)
    assert_success response
    assert_equal "1.07", response.params["purchase"]
    assert_equal "AP*", response.params["text_response"]
  end

  def test_4142
    @credit_card = credit_card("373953244361001", :verification_value => "1234")
    @options_with_billing = @options.merge(
      :merchant => '999',
      :billing_address => {
        :address1 => '123 St. ABC',
        :zip => '85016'
      }
    )
    response = @gateway.purchase(108, @credit_card, @options_with_billing)
    assert_success response

    void = @gateway.void(response.authorization, @options.merge(:try_reversal => true))
    assert_success void
  end


  def test_4344
    @credit_card = credit_card("6011900212345677", :verification_value => "123")
    @options_with_billing = @options.merge(
      :merchant => '999',
      :billing_address => {
        :address1 => '2500 Lake Cook Road',
        :zip => '80123'
      }
    )
    response = @gateway.authorize(109, @credit_card, @options_with_billing)
    assert_success response

    void = @gateway.void(response.authorization, @options.merge(:try_reversal => true))
    assert_success void
  end

  def test_4546
    @credit_card = credit_card("5439750001500248", :verification_value => "123")
    @options_with_billing = @options.merge(
      :merchant => '999',
      :billing_address => {
        :address1 => '4 Corporate SQ ',
        :zip => '30329'
      }
    )
    response = @gateway.purchase(110, @credit_card, @options_with_billing)
    assert_success response

    void = @gateway.void(response.authorization, @options.merge(:try_reversal => true))
    assert_success void
  end

    def test_5152
    response = @gateway.authorize(202, @credit_card_track_data, @options)
    assert_success response

    void = @gateway.void(response.authorization, @options.merge(:try_reversal => true))
    assert_success void
  end

  def test_5911
    @credit_card = credit_card("5439750001500248", :verification_value => "123")
    @options_with_billing = @options.merge(
      :merchant => '999',
      :billing_address => {
        :address1 => '4 Corporate SQ ',
        :zip => '30329'
      }
    )
    response = @gateway.purchase(110, @credit_card, @options_with_billing)
    assert_success response

    void = @gateway.void(response.authorization, @options.merge(:try_reversal => true))
    assert_success void
  end

  def test_512514
    @credit_card = credit_card("373953244361001", :verification_value => "1234")
    @options_with_billing = @options.merge(
      :merchant => '999',
      :billing_address => {
        :address1 => '123 St. ABC',
        :zip => '85016'
      }
    )
    response = @gateway.purchase(108, @credit_card, @options_with_billing)
    assert_success response

    void = @gateway.void(response.authorization, @options.merge(:try_reversal => true))
    assert_success void
  end



end
