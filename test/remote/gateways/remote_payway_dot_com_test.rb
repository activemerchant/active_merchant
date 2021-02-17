require 'test_helper'

class RemotePaywayDotComTest < Test::Unit::TestCase
  def setup
    @gateway = PaywayDotComGateway.new(fixtures(:payway_dot_com))

    @amount = 100
    @credit_card = credit_card('4000100011112224', verification_value: '737')
    @declined_card = credit_card('4000300011112220')
    @invalid_luhn_card = credit_card('4000300011112221')
    @options = {
      billing_address: address,
      description: 'Store Purchase',
      # source_id must be provided, contact payway support for valid source_id(s)
      source_id: '67'
    }
    @check = check(number: rand(0..100000), routing_number: '091000019')
    @check_invalid_aba = check({
      bank_name: 'TEST BANK',
      account_number: '000123456789',
      routing_number: '110000000'
    })
    @check_aba_too_short = check(routing_number: '54321')
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    #assert_equal 'REPLACE WITH SUCCESS MESSAGE', response.message
    assert_equal '5000', response.message[0,4]
  end

  def test_successful_purchase_with_more_options
    options = {
      order_id: '1',
      ip: "127.0.0.1",
      email: "joe@example.com",
      # source_id must be provided, contact payway support for valid source_id(s)
      source_id: '67',
      # change eci type, set to 5 for eCommerce 
      eci_type: '5',
      # set tax to 7 cents
      tax:      '7',
      # soft descriptor
      soft_descriptor: "Dan's Guitar Store"
    }

    # test email and eci_type and tax
    response = @gateway.purchase(101, @credit_card, options)
    assert_success response
    assert_equal '5000', response.message[0,4]
  end

  def test_failed_purchase
    #response = @gateway.purchase(@amount, @invalid_luhn_card, @options.merge( { test_result_code: '5012' }))
    response = @gateway.purchase(102, @invalid_luhn_card, @options)
    assert_failure response
    assert_equal PaywayDotComGateway::STANDARD_ERROR_CODE_MAPPING['5035'], response.error_code
    assert_equal '5035', response.message[0,4]
  end

  def test_successful_authorize
    auth_only = @gateway.authorize(103, @credit_card, @options)
    assert_success auth_only
    assert_equal '5000', auth_only.message[0,4]
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(104, @credit_card, @options)
    assert_success auth
    # need options to pass in source id 
    assert capture = @gateway.capture(@amount, auth.authorization, @options)
    assert_success capture
    assert_equal '5000', capture.message[0,4]
  end

  def test_failed_authorize
    response = @gateway.authorize(105, @invalid_luhn_card, @options)
    assert_failure response
    assert_equal '5035', response.message[0,4]
  end

  def test_failed_capture
    response = @gateway.capture(106, '')
    assert_failure response
    assert_equal '5025', response.message[0,4]
  end

  def test_successful_credit
    credit = @gateway.credit(107, @credit_card, @options)
    assert_success credit
    assert_equal '5000', credit.message[0,4]
  end

  # void authorization only
  def test_successful_void
    auth = @gateway.authorize(108, @credit_card, @options)
    assert_success auth

    # need options for passing required source id
    assert void = @gateway.void(auth.authorization, @options)
    assert_success void
    assert_equal '5000', void.message[0,4]
  end

  def test_failed_void
    response = @gateway.void('')
    assert_failure response
    assert_equal '5025', response.message[0,4]
  end

  # void of purchase (sale)
  def test_successful_void_of_sale
    sale = @gateway.purchase(109, @credit_card, @options)
    assert_success sale

    # need options for passing required source id
    assert void = @gateway.void(sale.authorization, @options)
    assert_success void
    assert_equal '5000', void.message[0,4]
  end

  # void of credit
  def test_successful_void_of_credit
    credit = @gateway.credit(110, @credit_card, @options)
    assert_success credit

    # need options for passing required source id
    assert void = @gateway.void(credit.authorization, @options)
    assert_success void
    assert_equal '5000', void.message[0,4]
  end

  def test_invalid_login
    gateway = PaywayDotComGateway.new(login: '', password: '', company_id: '')

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match %r{5001}, response.message[0,4]
  end

  def test_dump_transcript
    # This test will run a purchase transaction on your gateway
    # and dump a transcript of the HTTP conversation so that
    # you can use that transcript as a reference while
    # implementing your scrubbing logic.  You can delete
    # this helper after completing your scrub implementation.
    ##dump_transcript_and_fail(@gateway, @amount, @credit_card, @options)
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)
    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:password], transcript)
  end

end

