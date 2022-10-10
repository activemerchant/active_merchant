require 'test_helper'

class RemotePayArcTest < Test::Unit::TestCase
  def setup
    @gateway = PayArcGateway.new(fixtures(:pay_arc))
    credit_card_options = {
      month: '12',
      year: '2022',
      first_name: 'Rex Joseph',
      last_name: '',
      verification_value: '999'
    }
    @credit_card = credit_card('4111111111111111', credit_card_options)
    @invalid_credit_card = credit_card('3111111111111111', credit_card_options)
    @invalid_cvv_card = credit_card('4111111111111111', credit_card_options.update(verification_value: '123'))

    @amount = 100

    @options = {
      description: 'Store Purchase',
      card_source: 'INTERNET',
      billing_address: address.update(phone: '8772036624'),
      email: 'testy@test.com',
      phone: '8772036624'
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_block do
      PayArcGateway::SUCCESS_STATUS.include? response.message
    end
  end

  def test_successful_purchase_with_more_options
    extra_options = {
      order_id: '1',
      ip: '127.0.0.1',
      email: 'joe@example.com',
      tip_amount: 10
    }
    response = @gateway.purchase(1500, @credit_card, @options.merge(extra_options))
    assert_success response
    assert_block do
      PayArcGateway::SUCCESS_STATUS.include? response.message
    end
  end

  def test_successful_two_digit_card_exp_month
    credit_card_options = {
      month: '02',
      year: '2022',
      first_name: 'Rex Joseph',
      last_name: '',
      verification_value: '999'
    }
    credit_card = credit_card('4111111111111111', credit_card_options)

    response = @gateway.purchase(1022, credit_card, @options)
    assert_success response

    assert_block do
      PayArcGateway::SUCCESS_STATUS.include? response.message
    end
  end

  def test_successful_one_digit_card_exp_month
    credit_card_options = {
      month: '2',
      year: '2022',
      first_name: 'Rex Joseph',
      last_name: '',
      verification_value: '999'
    }
    credit_card = credit_card('4111111111111111', credit_card_options)

    response = @gateway.purchase(1022, credit_card, @options)
    assert_success response

    assert_block do
      PayArcGateway::SUCCESS_STATUS.include? response.message
    end
  end

  def test_failed_three_digit_card_exp_month
    credit_card_options = {
      month: '200',
      year: '2022',
      first_name: 'Rex Joseph',
      last_name: '',
      verification_value: '999'
    }
    credit_card = credit_card('4111111111111111', credit_card_options)

    response = @gateway.purchase(1022, credit_card, @options)
    assert_failure response
    assert_equal 'error', response.params['status']
  end

  def test_successful_adds_phone_number_for_purchase
    response = @gateway.purchase(250, @credit_card, @options)
    assert_success response

    assert_block do
      PayArcGateway::SUCCESS_STATUS.include? response.message
    end

    assert_equal '8772036624', response.params['data']['phone_number']
  end

  def test_successful_purchase_without_billing_address
    @options.delete(:billing_address)
    response = @gateway.purchase(250, @credit_card, @options)

    assert_nil response.params['data']['card']['data']['address1']
    assert_success response
  end

  def test_failed_purchase
    response = @gateway.purchase(1300, @invalid_credit_card, @options)
    assert_failure response
    assert_equal 'error', response.params['status']
  end

  def test_successful_authorize
    response = @gateway.authorize(1100, @credit_card, @options)
    assert_success response
    assert_equal 'authorized', response.message
  end

  # Failed due to invalid CVV
  def test_failed_authorize
    response = @gateway.authorize(500, @invalid_cvv_card, @options)
    assert_failure response
    assert_equal 'error', response.params['status']
  end

  def test_successful_authorize_and_capture
    authorize_response = @gateway.authorize(2000, @credit_card, @options)
    assert_success authorize_response
    response = @gateway.capture(2000, authorize_response.authorization, @options)
    assert_success response
    assert_block do
      PayArcGateway::SUCCESS_STATUS.include? response.message
    end
  end

  def test_failed_capture
    response = @gateway.capture(2000, 'invalid_txn_refernece', @options)
    assert_failure response
    assert_equal 'error', response.params['status']
  end

  def test_successful_void
    @options.update(reason: 'duplicate')
    charge_response = @gateway.purchase(1200, @credit_card, @options)
    assert_success charge_response

    assert void = @gateway.void(charge_response.authorization, @options)
    assert_success void
    assert_block do
      PayArcGateway::SUCCESS_STATUS.include? void.message
    end
  end

  def test_failed_void
    response = @gateway.void('invalid_txn_reference', @options)
    assert_failure response
    assert_equal 'error', response.params['status']
  end

  def test_partial_capture
    authorize_response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorize_response

    response = @gateway.capture(@amount - 1, authorize_response.authorization, @options)
    assert_success response
    assert_block do
      PayArcGateway::SUCCESS_STATUS.include? response.message
    end
  end

  def test_successful_refund
    purchase = @gateway.purchase(900, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(900, purchase.authorization)
    assert_success refund
    assert_block do
      PayArcGateway::SUCCESS_STATUS.include? refund.message
    end
    assert_equal 'refunded', refund.message
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount - 1, purchase.authorization)
    assert_success refund
    assert_block do
      PayArcGateway::SUCCESS_STATUS.include? refund.message
    end
    assert_equal 'partial_refund', refund.message
  end

  def test_failed_refund
    response = @gateway.refund(1200, '')
    assert_failure response
    assert_equal 'error', response.params['status']
  end

  def test_successful_credit
    response = @gateway.credit(250, @credit_card, @options)
    assert_success response
    assert_block do
      PayArcGateway::SUCCESS_STATUS.include? response.message
    end
    assert_equal 'refunded', response.message
  end

  def test_failed_credit
    response = @gateway.credit('', @invalid_credit_card, @options)
    assert_failure response
    assert_equal 'error', response.params['status']
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
  end

  def test_failed_verify
    response = @gateway.verify(@invalid_credit_card, @options)
    assert_failure response
    assert_block do
      !(200..299).cover? response.error_code
    end
  end

  def test_invalid_login
    gateway = PayArcGateway.new(api_key: '<invalid bearer token>')

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'error', response.params['status']
    assert_block do
      !(200..299).cover? response.error_code
    end
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)
    assert_scrubbed(fixtures(:pay_arc), transcript)
    assert_scrubbed(/card_number=#{@credit_card.number}/, transcript)
    assert_scrubbed(/cvv=#{@credit_card.verification_value}/, transcript)
  end
end
