require 'test_helper'

class RemoteMercuryTest < Test::Unit::TestCase
  def setup
    Base.gateway_mode = :test

    @gateway = MercuryGateway.new(fixtures(:mercury))

    @amount = 100

    @mc = credit_card("5499990123456781", :brand => "master")
    @discover = credit_card("6011000997235373", :brand => "discover")
    @amex = credit_card("373953244361001", :brand => "american_express", :verification_value => "1234")
    @visa = credit_card("4003000123456781", :brand => "visa")

    @declined_card = credit_card('4000300011112220')

    @options = {
      :merchant => 'test',
      :description => "Open Dining Mercury Integration v1.0"
    }
    @options_with_billing = {
      :merchant => '999',
      :description => "Open Dining Mercury Integration v1.0",
      :billing_address => {
        :address1 => '4 Corporate Square',
        :zip => '30329'
      }
    }
    @full_options = {
      :order_id => '1',
      :ip => '123.123.123.123',
      :merchant => "Open Dining",
      :description => "Open Dining Integration",
      :customer => "Tim",
      :tax => "5",
      :billing_address => {
        :address1 => '4 Corporate Square',
        :zip => '30329'
      }
    }

    @visa_partial_card = credit_card("4005550000000480")
  end

  def test_visa_pre_auth_and_capture_swipe
    order_id = 500
    assert visa_response = @gateway.authorize(100, @visa, @options.merge(:order_id => order_id))
    assert_success visa_response
    assert_equal '1.00', visa_response.params['authorize']

    assert visa_capture = @gateway.capture(100, visa_response.authorization, :credit_card => @visa)
    assert_success visa_capture
    assert_equal '1.00', visa_capture.params['authorize']
  end

  def test_mastercard_pre_auth_and_capture_with_refund
    order_id = 501
    assert mc_response = @gateway.authorize(200, @mc, @options.merge(:order_id => order_id))
    assert_success mc_response
    assert_equal '2.00', mc_response.params['authorize']

    assert mc_capture = @gateway.capture(200, mc_response.authorization, :credit_card => @mc)
    assert_success mc_capture
    assert_equal '2.00', mc_capture.params['authorize']

    assert refund_response = @gateway.refund(200, mc_capture.authorization, :credit_card => @mc)

    assert_success refund_response
    assert_equal '2.00', refund_response.params['purchase']
    assert_equal 'VoidSale', refund_response.params['tran_code']
  end

  def test_visa_pre_auth_and_capture_manual
    order_id = 502
    assert response = @gateway.authorize(300, @visa, @options.merge(:order_id => order_id))
    assert_success response
    assert_equal '3.00', response.params['authorize']

    assert capture = @gateway.capture(300, response.authorization, :credit_card => @visa)
    assert_success capture
    assert_equal '3.00', capture.params['authorize']
  end

  def test_mastercard_pre_auth_and_capture_manual
    order_id = 503
    assert mc_response = @gateway.authorize(400, @mc, @options_with_billing.merge(:order_id => order_id))
    assert_success mc_response
    assert_equal '4.00', mc_response.params['authorize']

    assert mc_capture = @gateway.capture(400, mc_response.authorization, :credit_card => @mc, :tip => 150)
    assert_success mc_capture
    assert_equal '5.50', mc_capture.params['authorize']
  end

  def test_amex_pre_auth_capture_and_return_manual
    order_id = 201
    assert response = @gateway.authorize(201, @amex, @options_with_billing.merge(:order_id => order_id))
    assert_success response
    assert_equal '2.01', response.params['authorize']

    assert capture = @gateway.capture(201, response.authorization, :credit_card => @amex)
    assert_success capture
    assert_equal '2.01', capture.params['authorize']

    assert response = @gateway.credit(201, @amex, @options_with_billing.merge(:order_id => order_id))
    assert_success response
    assert_equal '2.01', response.params['purchase']
  end

  def test_discover_pre_auth_and_capture
    order_id = 506
    assert response = @gateway.authorize(225, @discover, @options_with_billing.merge(:order_id => order_id))
    assert_success response
    assert_equal '2.25', response.params['authorize']

    assert capture = @gateway.capture(225, response.authorization, :credit_card => @discover)
    assert_success capture
    assert_equal '2.25', capture.params['authorize']
  end

  def test_mastercard_return_manual
    order_id = 508
    assert response = @gateway.credit(425, @mc, @options.merge(:order_id => order_id))
    assert_success response
    assert_equal '4.25', response.params['purchase']
  end

  def test_visa_pre_auth_failure_swipe
    order_id = 509
    assert response = @gateway.authorize(1100, @visa, @options.merge(:order_id => order_id))
    assert_failure response
    assert_equal "DECLINE", response.message
  end

  def test_mastercard_pre_auth_date_failure_manual
    order_id = 510
    @mc.month = 13
    @mc.year = 2001
    assert response = @gateway.authorize(575, @mc, @options_with_billing.merge(:order_id => order_id))
    assert_failure response
    assert_equal "INVLD EXP DATE", response.message
  end

  def test_visa_sale_swipe
    order_id = 511
    assert response = @gateway.purchase(50, @visa, @options.merge(:order_id => order_id))

    assert_success response
    assert_equal "0.50", response.params["purchase"]
  end

  def test_mastercard_sale_manual
    order_id = 512
    assert response = @gateway.purchase(75, @mc, @options.merge(:order_id => order_id))

    assert_success response
    assert_equal "0.75", response.params["purchase"]
  end

  def test_visa_preauth_avs_cvv_manual
    order_id = 513
    assert response = @gateway.authorize(333, @visa, @options_with_billing.merge(:order_id => order_id))

    assert_success response
    assert_equal response.avs_result, {"code" => "Y", "postal_match" => "Y", "street_match" => "Y",
      "message" => "Street address and 5-digit postal code match."}
  end

  def test_mastercard_bad_preauth_avs_cvv_manual
    order_id = 513
    @mc.month = 8
    @mc.year = 2013
    @mc.verification_value = 321
    @options_with_billing[:billing_address] = {:address => "wrong address", :zip => "12345"}

    assert response = @gateway.authorize(444, @mc, @options_with_billing.merge(:order_id => order_id))

    assert_success response
    assert_equal response.avs_result, {"code" => "N", "postal_match" => "N", "street_match" => "N",
      "message" => "Street address and postal code do not match."}

  end

  def test_preauth_partial_auth_visa
    @order_id = 156
    assert response = @gateway.authorize(2354, @visa_partial_card, @options.merge(:order_id => @order_id))

    assert_success response

    assert capture = @gateway.capture(2000, response.authorization, :credit_card => @visa_partial_card)
    assert_success capture

    assert reverse = @gateway.refund(2000, capture.authorization, :credit_card => @visa_partial_card)
    assert_success reverse
  end

  def test_preauth_partial_discover
    @order_id = 157
    assert response = @gateway.authorize(2307, @discover, @options.merge(:order_id => @order_id))
    assert_success response

    assert capture = @gateway.capture(2000, response.authorization, :credit_card => @discover)
    assert_success capture

    assert reverse = @gateway.refund(2000, capture.authorization, :credit_card => @discover)
    assert_success reverse
  end
end
