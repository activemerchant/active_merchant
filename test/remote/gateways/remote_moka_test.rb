require 'test_helper'

class RemoteMokaTest < Test::Unit::TestCase
  def setup
    @gateway = MokaGateway.new(fixtures(:moka))

    @amount = 100
    @credit_card = credit_card('5269111122223332')
    @declined_card = credit_card('4000300011112220')
    @options = {
      description: 'Store Purchase'
    }
    @three_ds_options = @options.merge({
      execute_threed: true,
      redirect_type: 1,
      redirect_url: 'www.example.com'
    })
  end

  def test_invalid_login
    gateway = MokaGateway.new(dealer_code: '', username: '', password: '')

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match 'PaymentDealer.CheckPaymentDealerAuthentication.InvalidAccount', response.message
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_successful_purchase_with_single_digit_exp_month
    @credit_card.month = 1
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_successful_purchase_with_more_options
    options = {
      order_id: '1',
      ip: '127.0.0.1',
      sub_merchant_name: 'Example Co.',
      is_pool_payment: 1
    }

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_successful_purchase_with_buyer_information
    options = {
      billing_address: address,
      email: 'safiye.ali@example.com'
    }

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_successful_purchase_with_basket_products
    # Basket Products must be on the list of Merchant Products for your Moka account.
    # To see this list or add products to it, log in to your Moka Dashboard
    options = {
      basket_product: [
        {
          product_id: 333,
          product_code: '0173',
          unit_price: 19900,
          quantity: 1
        },
        {
          product_id: 281,
          product_code: '38',
          unit_price: 5000,
          quantity: 1
        }
      ]
    }

    response = @gateway.purchase(24900, @credit_card, options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_successful_purchase_with_nil_cvv
    test_card = credit_card('5269111122223332')
    test_card.verification_value = nil

    response = @gateway.purchase(@amount, test_card, @options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_successful_purchase_with_installments
    options = @options.merge(installment_number: 12)
    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response

    assert_equal 'PaymentDealer.DoDirectPayment.VirtualPosNotAvailable', response.message
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal 'Success', capture.message
  end

  def test_successful_authorize_and_capture_using_non_default_currency
    options = @options.merge(currency: 'USD')
    auth = @gateway.authorize(@amount, @credit_card, options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization, currency: 'USD')
    assert_success capture
    assert_equal 'Success', capture.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'PaymentDealer.DoDirectPayment.VirtualPosNotAvailable', response.error_code
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount - 0.1, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    response = @gateway.capture(@amount, '')
    assert_failure response
    assert_equal 'PaymentDealer.DoCapture.OtherTrxCodeOrVirtualPosOrderIdMustGiven', response.message
  end

  # # Moka does not allow a same-day refund on a purchase/capture. In order to test refund,
  # # you must pass a reference that has 'matured' at least one day.
  # def test_successful_refund
  #   my_matured_reference = 'REPLACE ME'
  #   assert refund = @gateway.refund(0, my_matured_reference)
  #   assert_success refund
  #   assert_equal 'Success', refund.message
  # end

  # # Moka does not allow a same-day refund on a purchase/capture. In order to test refund,
  # # you must pass a reference that has 'matured' at least one day. For the purposes of testing
  # # a partial refund, make sure the original transaction being referenced was for an amount
  # # greater than the 'partial_amount' supplied in the test.
  # def test_partial_refund
  #   my_matured_reference = 'REPLACE ME'
  #   partial_amount = 50
  #   assert refund = @gateway.refund(partial_amount, my_matured_reference)
  #   assert_success refund
  #   assert_equal 'Success', refund.message
  # end

  def test_failed_refund
    response = @gateway.refund(@amount, '')
    assert_failure response
    assert_equal 'PaymentDealer.DoCreateRefundRequest.OtherTrxCodeOrVirtualPosOrderIdMustGiven', response.message
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal 'Success', void.message
  end

  def test_failed_void
    response = @gateway.void('')
    assert_failure response
    assert_equal 'PaymentDealer.DoVoid.InvalidRequest', response.message
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match 'Success', response.message
  end

  def test_failed_verify
    response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_match 'PaymentDealer.DoDirectPayment.VirtualPosNotAvailable', response.message
  end

  # 3ds Tests

  def test_successful_initiation_of_3ds_authorize
    response = @gateway.authorize(@amount, @credit_card, @three_ds_options)

    assert_success response
    assert_equal 'Success', response.message
    assert response.params['Data']['Url'].present?
    assert response.params['Data']['CodeForHash'].present?
  end

  def test_failed_3ds_authorize
    response = @gateway.authorize(@amount, @declined_card, @three_ds_options)

    assert_failure response
    assert_equal 'PaymentDealer.DoDirectPayment3dRequest.VirtualPosNotAvailable', response.message
  end

  def test_successful_initiation_of_3ds_purchase
    response = @gateway.purchase(@amount, @credit_card, @three_ds_options)

    assert_success response
    assert_equal 'Success', response.message
    assert response.params['Data']['Url'].present?
    assert response.params['Data']['CodeForHash'].present?
  end

  def test_failed_3ds_purchase
    response = @gateway.purchase(@amount, @declined_card, @three_ds_options)

    assert_failure response
    assert_equal 'PaymentDealer.DoDirectPayment3dRequest.VirtualPosNotAvailable', response.message
  end

  # Scrubbing Tests

  def test_transcript_scrubbing_with_string_dealer_code
    gateway = MokaGateway.new(fixtures(:moka))
    gateway.options[:dealer_code] = gateway.options[:dealer_code].to_s

    capture_transcript_and_assert_scrubbed(gateway)
  end

  def test_transcript_scrubbing_with_integer_dealer_code
    gateway = MokaGateway.new(fixtures(:moka))
    gateway.options[:dealer_code] = gateway.options[:dealer_code].to_i

    capture_transcript_and_assert_scrubbed(gateway)
  end

  def capture_transcript_and_assert_scrubbed(gateway)
    transcript = capture_transcript(gateway) do
      gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(gateway.options[:dealer_code], transcript)
    assert_scrubbed(gateway.options[:username], transcript)
    assert_scrubbed(gateway.options[:password], transcript)
    assert_scrubbed(check_key, transcript)
  end

  def check_key
    str = "#{@gateway.options[:dealer_code]}MK#{@gateway.options[:username]}PD#{@gateway.options[:password]}"
    Digest::SHA256.hexdigest(str)
  end
end
