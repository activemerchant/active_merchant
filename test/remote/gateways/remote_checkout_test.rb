require 'test_helper'

class RemoteCheckoutTest < Test::Unit::TestCase
  
  def setup

    # Gateway credentials
    @gateway = ActiveMerchant::Billing::CheckoutGateway.new(
      :MerchantCode    => 'SBMTEST',    # Merchant Code
      :Password => 'Password1!',          # Processing Password
      :gatewayURL => 'https://api.checkout.com/Process/gateway.aspx' # optional - Gateway URL
    )

    # Create a new credit card object
    @credit_card = ActiveMerchant::Billing::CreditCard.new(
      :number     => '4543474002249996',
      :month      => '06',
      :year       => '2017',
      :name  => 'Checkout Testing', # Card holder name
      :verification_value  => '956'
    )

    # Create a new credit card object
    @declined_card  = ActiveMerchant::Billing::CreditCard.new(
      :number     => '4543474002249996',
      :month      => '06',
      :year       => '2018',
      :name  => 'Checkout Testing', # Card holder name
      :verification_value  => '958'
    )

    # Additional information
    @options = {

        :currency       => 'EUR',
        :order_id       => 'Test - 1001',
        :email        => 'bill_email@email.com',

        # Billing Details
        :billing_address => {
          :address1     => 'bill_address',
          :city       => 'bill_city',
          :state      => 'bill_state',
          :zip        => '02346',
          :country    => 'US',
          :phone      => '2308946513541'
        },

        # Shipping Details
        :shipping_address   => {
          :address1     => 'ship_address',
          :address2     => 'ship_address2',
          :city       => 'ship_city',
          :state      => 'ship_state',
          :zip        => '02346',
          :country    => 'US',
          :phone      => '2308946513542'
        },

        # Other fields
        :ip         => '127.0.0.1',
        :customer       => '123456498'
    }

    # Amount in cents
    @amount = 100
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Successful', response.params["result"]
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Not Successful', response.params["result"]
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.params["tranid"], @options)
    assert_success capture
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
  end
end
