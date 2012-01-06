require 'test_helper'

class PaypalExpressTest < Test::Unit::TestCase
  def setup
    Base.gateway_mode = :test

    @gateway = PaypalExpressGateway.new(fixtures(:paypal_certificate))

    @options = {
      :order_id => '230000',
      :email => 'buyer@jadedpallet.com',
      :billing_address => { :name => 'Fred Brooks',
                    :address1 => '1234 Penny Lane',
                    :city => 'Jonsetown',
                    :state => 'NC',
                    :country => 'US',
                    :zip => '23456'
                  } ,
      :description => 'Stuff that you purchased, yo!',
      :ip => '10.0.0.1',
      :return_url => 'http://example.com/return',
      :cancel_return_url => 'http://example.com/cancel'
    }
  end

  def test_set_express_authorization
    @options.update(
      :return_url => 'http://example.com',
      :cancel_return_url => 'http://example.com',
      :email => 'Buyer1@paypal.com'
    )
    response = @gateway.setup_authorization(500, @options)
    assert response.success?
    assert response.test?
    assert !response.params['token'].blank?
  end

  def test_set_express_purchase
    @options.update(
      :return_url => 'http://example.com',
      :cancel_return_url => 'http://example.com',
      :email => 'Buyer1@paypal.com'
    )
    response = @gateway.setup_purchase(500, @options)
    assert response.success?
    assert response.test?
    assert !response.params['token'].blank?
  end

  def test_set_express_order
    @options.update(
      :return_url => 'http://example.com',
      :cancel_return_url => 'http://example.com',
      :email => 'Buyer1@paypal.com'
    )
    response = @gateway.setup_order(500, @options)
    assert response.success?
    assert response.test?
    assert !response.params['token'].blank?
  end

  # NOTE: multiple auths per order needs to be specifically enabled on your test account.
  # Create your order elsewhere and drop-in the ID here.
  def test_successful_order_flow
    order_id = "O-2J515159AF8397729" # $100

    # first authorization...
    auth_one = @gateway.authorize_order(5000, order_id, :currency => 'CAD')
    assert_success auth_one
    assert auth_one.params['transaction_id']

    # capture it...
    response = @gateway.capture(5000, auth_one.authorization, :currency => 'CAD')
    assert_success response
    assert response.params['transaction_id']
    assert_equal '50.00', response.params['gross_amount']

    # second authorization...
    auth_two = @gateway.authorize_order(6500, order_id, :currency => 'CAD') # multi-auths up to 115% of order amount
    assert_success auth_two
    assert auth_two.params['transaction_id']

    # capture it...
    response = @gateway.capture(6500, auth_two.authorization, :currency => 'CAD')
    assert_success response
    assert response.params['transaction_id']
    assert_equal '65.00', response.params['gross_amount']
  end

end
