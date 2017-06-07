require 'test_helper'

class RemotePelotonCustomerServiceTest < Test::Unit::TestCase
  def setup
    Base.mode = :test

    @gateway = PelotonCustomerServiceGateway.new(fixtures(:peloton))

    @credit_card = ActiveMerchant::Billing::CreditCard.new(
        :number => 4030000010001234,
        :month => 8,
        :year => 2016,
        :first_name => 'xiaobo',
        :last_name => 'zzz',
        :verification_value => 123,
        :brand => 'visa'
    )

    @declined_card = ActiveMerchant::Billing::CreditCard.new(
        :number => 4003050500040005,
        :month => 8,
        :year => 2016,
        :first_name => 'xiaobo',
        :last_name => 'zzz',
        :verification_value => 123,
        :brand => 'visa'
    )

    @amount = 1000

    @options = {
        :canadian_address_verification => false,
        :order_id => '115',
        :language_code => 'EN',
        :email => 'john@example.com',
        :customer_id => SecureRandom.hex(15),
        :billing_address => {
            :name => "John",
            :address1 => "772 1 Ave",
            :address2 => "",
            :city => "Calgary",
            :state => "AB",
            :country => "CA",
            :zip => "T2N 0A3",
            :phone => "5872284918",
        },
        :shipping_address => {
            :name => "John",
            :address1 => "772 1 Ave",
            :address2 => "",
            :city => "Calgary",
            :state => "AB",
            :country => "CA",
            :zip => "T2N 0A3",
            :phone => "5872284918",
        }
    }
  end

  def test_successful_create
    response = @gateway.create(@credit_card, @options)
    assert_success response
    assert_equal @options[:order_id], response.authorization.split(';')[0]
  end

  def test_failed_create
    response = @gateway.create(@declined_card, @options)
    assert_failure response
    assert_equal nil, response.authorization.split(';')[0]
  end
  # def test_successful_purchase
  #   response = @gateway.purchase(@amount, @credit_card, @options)
  #   assert_success response
  #   assert_equal 'REPLACE WITH SUCCESS MESSAGE', response.message
  # end
  #
  # def test_failed_purchase
  #   response = @gateway.purchase(@amount, @declined_card, @options)
  #   assert_failure response
  #   assert_equal 'REPLACE WITH FAILED PURCHASE MESSAGE', response.message
  # end
  #
  # def test_successful_authorize_and_capture
  #   auth = @gateway.authorize(@amount, @credit_card, @options)
  #   assert_success auth
  #
  #   assert capture = @gateway.capture(nil, auth.authorization)
  #   assert_success capture
  # end
  #
  # def test_failed_authorize
  #   response = @gateway.authorize(@amount, @declined_card, @options)
  #   assert_failure response
  # end
  #
  # def test_partial_capture
  #   auth = @gateway.authorize(@amount, @credit_card, @options)
  #   assert_success auth
  #
  #   assert capture = @gateway.capture(@amount-1, auth.authorization)
  #   assert_success capture
  # end
  #
  # def test_failed_capture
  #   response = @gateway.capture(nil, '')
  #   assert_failure response
  # end
  #
  # def test_successful_refund
  #   purchase = @gateway.purchase(@amount, @credit_card, @options)
  #   assert_success purchase
  #
  #   assert refund = @gateway.refund(nil, purchase.authorization)
  #   assert_success refund
  # end
  #
  # def test_partial_refund
  #   purchase = @gateway.purchase(@amount, @credit_card, @options)
  #   assert_success purchase
  #
  #   assert refund = @gateway.refund(@amount-1, purchase.authorization)
  #   assert_success refund
  # end
  #
  # def test_failed_refund
  #   response = @gateway.refund(nil, '')
  #   assert_failure response
  # end
  #
  # def test_successful_void
  #   auth = @gateway.authorize(@amount, @credit_card, @options)
  #   assert_success auth
  #
  #   assert void = @gateway.void(auth.authorization)
  #   assert_success void
  # end
  #
  # def test_failed_void
  #   response = @gateway.void('')
  #   assert_failure response
  # end
  #
  # def test_successful_verify
  #   response = @gateway.verify(@credit_card, @options)
  #   assert_success response
  #   assert_match %r{REPLACE WITH SUCCESS MESSAGE}, response.message
  # end
  #
  # def test_failed_verify
  #   response = @gateway.verify(@declined_card, @options)
  #   assert_failure response
  #   assert_match %r{REPLACE WITH FAILED PURCHASE MESSAGE}, response.message
  # end
  #
  # def test_invalid_login
  #   gateway = PelotonCustomerServiceGateway.new(
  #     login: '',
  #     password: ''
  #   )
  #   response = gateway.purchase(@amount, @credit_card, @options)
  #   assert_failure response
  # end
end
