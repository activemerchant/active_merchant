require 'test_helper'
require "support/mercury_helper"

class RemoteMercuryCertificationTest < Test::Unit::TestCase
  include MercuryHelper

  # Tokenization

  def test_sale_and_reversal
    close_batch(tokenization_gateway)

    sale = tokenization_gateway.purchase(101, visa, options("1"))
    assert_success sale
    assert_equal "AP", sale.params["text_response"]

    reversal = tokenization_gateway.void(sale.authorization, options.merge(:try_reversal => true))
    assert_success reversal
    assert_equal "REVERSED", reversal.params["text_response"]
  end

  def test_sale_and_void
    close_batch(tokenization_gateway)

    sale = tokenization_gateway.purchase(103, visa, options("1"))
    assert_success sale
    assert_equal "AP", sale.params["text_response"]

    void = tokenization_gateway.void(sale.authorization, options)
    assert_success void
    assert_equal "AP", void.params["text_response"]
  end

  def test_preauth_capture_and_reversal
    close_batch(tokenization_gateway)

    cc = credit_card(
      "4005550000000480",
      :brand => "visa",
      :month => "12",
      :year => "15",
      :verification_value => "123"
    )

    preauth = tokenization_gateway.authorize(106, cc, options("1"))
    assert_success preauth
    assert_equal "AP", preauth.params["text_response"]

    capture = tokenization_gateway.capture(106, preauth.authorization, options)
    assert_success capture
    assert_equal "AP", capture.params["text_response"]

    reversal = tokenization_gateway.void(capture.authorization, options.merge(:try_reversal => true))
    assert_success reversal
    assert_equal "REVERSED", reversal.params["text_response"]
  end

  def test_return
    close_batch(tokenization_gateway)

    credit = tokenization_gateway.credit(109, visa, options("1"))
    assert_success credit
    assert_equal "AP", credit.params["text_response"]
  end

  def test_preauth_and_reversal
    close_batch(tokenization_gateway)

    preauth = tokenization_gateway.authorize(113, disc, options("1"))
    assert_success preauth
    assert_equal "AP", preauth.params["text_response"]

    reversal = tokenization_gateway.void(preauth.authorization, options.merge(:try_reversal => true))
    assert_success reversal
    assert_equal "REVERSED", reversal.params["text_response"]
  end

  def test_preauth_capture_and_reversal
    close_batch(tokenization_gateway)

    preauth = tokenization_gateway.authorize(106, visa, options("1"))
    assert_success preauth
    assert_equal "AP", preauth.params["text_response"]

    capture = tokenization_gateway.capture(206, preauth.authorization, options)
    assert_success capture
    assert_equal "AP", capture.params["text_response"]

    void = tokenization_gateway.void(capture.authorization, options)
    assert_success void
    assert_equal "AP", void.params["text_response"]
  end

  private

  def tokenization_gateway
    @tokenization_gateway ||= MercuryGateway.new(
      :login => "023358150511666",
      :password => "xyz"
    )
  end

  def visa
    @visa ||= credit_card(
      "4003000123456781",
      :brand => "visa",
      :month => "12",
      :year => "15",
      :verification_value => "123"
    )
  end

  def disc
    @disc ||= credit_card(
      "6011000997235373",
      :brand => "discover",
      :month => "12",
      :year => "15",
      :verification_value => "362"
    )
  end

  def mc
    @mc ||= credit_card(
      "5439750001500248",
      :brand => "master",
      :month => "12",
      :year => "15",
      :verification_value => "123"
    )
  end

  def options(order_id=nil, other={})
    {
      :order_id => order_id,
      :description => "ActiveMerchant",
    }.merge(other)
  end
end
