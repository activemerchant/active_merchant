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

    reversal = tokenization_gateway.refund(101, sale.authorization, options)
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
    assert_equal "REVERSED", void.params["text_response"]
  end

  def test_preauth_capture_and_reversal
    close_batch(tokenization_gateway)

    preauth = tokenization_gateway.authorize(106, visa, options("1"))
    assert_success preauth
    assert_equal "AP", preauth.params["text_response"]

    capture = tokenization_gateway.capture(106, preauth.authorization, options)
    assert_success capture
    assert_equal "AP", capture.params["text_response"]

    reversal = tokenization_gateway.refund(106, capture.authorization, options)
    assert_success reversal
    assert_equal "REVERSED", reversal.params["text_response"]
  end

  def test_preauth_and_reversal
    close_batch(tokenization_gateway)

    preauth = tokenization_gateway.authorize(113, visa, options("1"))
    assert_success preauth
    assert_equal "AP", preauth.params["text_response"]

    reversal = tokenization_gateway.void(preauth.authorization, options)
    assert_success reversal
    assert_equal "REVERSED", reversal.params["text_response"]
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

  def options(order_id=nil, other={})
    {
      :order_id => order_id,
      :description => "ActiveMerchant",
    }.merge(other)
  end
end
