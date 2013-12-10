require 'test_helper'
require 'rest-client'

class RemoteSlidepayTest < Test::Unit::TestCase

  def setup
    # RestClient.proxy = "https://127.0.0.1:8888"
    @gateway = SlidepayGateway.new(fixtures(:slidepay))

    @amount = 101
    @credit_card = credit_card('4111111111111111')
    @declined_card = credit_card('4000300011112220')

    @options = {
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    # assert_equal 'REPLACE WITH SUCCESS MESSAGE', response.message
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    # assert_equal 'REPLACE WITH FAILED PURCHASE MESSAGE', response.message
  end

  def test_invalid_login
    # reset SlidePay variables
    SlidePay.token = nil
    SlidePay.api_key = nil
    SlidePay.endpoint = nil

    #Should raise an exception when the gateway tries to authenticate
    assert_raise SlidepayGateway::SlidePayAuthenticationError do
      gateway = SlidepayGateway.new(
                  :email => '',
                  :password => '',
                  :is_test => true
                )
    end
  end

  def credit_card(number = '4242424242424242', options = {})
    defaults = {
      :number => number,
      :month => 11,
      :year => Time.now.year + 1,
      :first_name => 'Longbob',
      :last_name => 'Longsen',
      :verification_value => '111',
      :brand => 'visa'
    }.update(options)

    ActiveMerchant::Billing::CreditCard.new(defaults)
  end

  def address(options = {})
    {
      :name     => 'Jim Smith',
      :address1 => '1234 My Street',
      :address2 => 'Apt 1',
      :company  => 'Widgets Inc',
      :city     => 'Mountain View',
      :state    => 'CA',
      :zip      => '11111',
      :country  => 'USA',
      :phone    => '(555)555-5555',
      :fax      => '(555)555-6666'
    }.update(options)
  end
end
