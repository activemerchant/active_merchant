require 'test_helper'

class RemoteSlidepayTest < Test::Unit::TestCase

  def setup
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

  # purchase
  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
  end

  # def test_unsuccessful_purchase
  #   assert response = @gateway.purchase(@amount, @declined_card, @options)
  #   assert_failure response
  # end

  # credit
  def test_successful_credit
    purchase_response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase_response

    payment_id = purchase_response.params["payment_id"]
    response = @gateway.credit(payment_id)
    assert_success response
  end

  def test_unsuccessful_credit
    bad_payment_id = "11626"
    response = @gateway.credit(bad_payment_id)
    assert_failure response
  end

  # authorize
  def test_successful_authorize
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
  end

  def test_unsuccessful_authorize
    assert response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
  end

  # capture
  def test_successful_capture
    authorize_response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorize_response

    payment_id = authorize_response.params["payment_id"]
    response = @gateway.capture(payment_id)
    assert_success response
  end

  def test_unsuccessful_capture
    bad_payment_id = "000000000"
    response = @gateway.capture(bad_payment_id)
    assert_failure response
  end

  # void
  # def test_successful_void
  #   authorize_response = @gateway.authorize(@amount, @credit_card, @options)
  #   assert_success authorize_response

  #   payment_id = authorize_response.params["payment_id"]
  #   response = @gateway.void(payment_id)
  #   assert_success response
  # end

  def test_unsuccessful_void
    bad_payment_id = "000000000"
    response = @gateway.void(bad_payment_id)
    assert_failure response
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
