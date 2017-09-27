require 'test_helper'

class RemoteOppTest < Test::Unit::TestCase

  def setup
    @gateway = OppGateway.new(fixtures(:opp))
    @amount = 100

    @valid_card = credit_card("4200000000000000", month: 05, year: 2018)
    @invalid_card = credit_card("4444444444444444", month: 05, year: 2018)
    @amex_card = credit_card("377777777777770 ", month: 05, year: 2018, brand: 'amex', verification_value: '1234')

    request_type = 'complete' # 'minimal' || 'complete'
    time = Time.now.to_i
    ip = '101.102.103.104'
    @complete_request_options = {
      order_id: "Order #{time}",
      merchant_transaction_id: "active_merchant_test_complete #{time}",
      address: address,
      description: 'Store Purchase - Books',
#      riskWorkflow: true,
#      testMode: 'EXTERNAL' # or 'INTERNAL', valid only for test system

        billing_address: {
           address1: '123 Test Street',
           city:     'Test',
           state:    'TE',
           zip:      'AB12CD',
           country:  'GB',
         },
         shipping_address: {
           name:     'Muton DeMicelis',
           address1: 'My Street On Upiter, Apt 3.14/2.78',
           city:     'Munich',
           state:    'Bov',
           zip:      '81675',
           country:  'DE',
         },
         customer: {
           merchant_customer_id:  "your merchant/customer id",
           givenName:  'Jane',
           surname:  'Jones',
           birthDate:  '1965-05-01',
           phone:  '(?!?)555-5555',
           mobile:  '(?!?)234-23423',
           email:  'jane@jones.com',
           company_name:  'JJ Ltd.',
           identification_doctype:  'PASSPORT',
           identification_docid:  'FakeID2342431234123',
           ip:  ip,
         },
    }

    @minimal_request_options = {
      order_id: "Order #{time}",
      description: 'Store Purchase - Books',
    }

    @complete_request_options['customParameters[SHOPPER_test124TestName009]'] = 'customParameters_test'
    @complete_request_options['customParameters[SHOPPER_otherCustomerParameter]'] = 'otherCustomerParameter_test'

    @test_success_id = "8a82944a4e008ca9014e1273e0696122"
    @test_failure_id = "8a8294494e0078a6014e12b371fb6a8e"
    @test_wrong_reference_id = "8a8444494a0033a6014e12b371fb6a1e"

    @options = @minimal_request_options if request_type == 'minimal'
    @options = @complete_request_options if request_type == 'complete'
  end

# ****************************************** SUCCESSFUL TESTS ******************************************
  def test_successful_purchase
    @options[:description] = __method__

    response = @gateway.purchase(@amount, @valid_card, @options)
    assert_success response, "Failed purchase"
    assert_match %r{Request successfully processed}, response.message

    assert response.test?
  end

  def test_successful_purchase_sans_options
    response = @gateway.purchase(@amount, @valid_card)
    assert_success response
    assert_match %r{Request successfully processed}, response.message

    assert response.test?
  end

  def test_successful_authorize
    @options[:description] = __method__

    response = @gateway.authorize(@amount, @valid_card, @options)
    assert_success response, "Authorization Failed"
    assert_match %r{Request successfully processed}, response.message

    assert response.test?
  end

  def test_successful_capture
    @options[:description] = __method__
    auth = @gateway.authorize(@amount, @valid_card, @options)
    assert_success auth, "Authorization Failed"
    assert auth.test?

    capt = @gateway.capture(@amount, auth.authorization, @options)
    assert_success capt, "Capture failed"
    assert_match %r{Request successfully processed}, capt.message

    assert capt.test?
  end

  def test_successful_refund
    @options[:description] = __method__
    purchase = @gateway.purchase(@amount, @valid_card, @options)
    assert_success purchase, "Purchase failed"
    assert purchase.test?

    refund = @gateway.refund(@amount, purchase.authorization, @options)
    assert_success refund, "Refund failed"
    assert_match %r{Request successfully processed}, refund.message

    assert refund.test?
  end

  def test_successful_void
    @options[:description] = __method__
    purchase = @gateway.purchase(@amount, @valid_card, @options)
    assert_success purchase, "Purchase failed"
    assert purchase.test?

    void = @gateway.void(purchase.authorization, @options)
    assert_success void, "Void failed"
    assert_match %r{Request successfully processed}, void.message

    assert void.test?
  end

  def test_successful_partial_capture
    @options[:description] = __method__
    auth = @gateway.authorize(@amount, @valid_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount-1, auth.authorization)
    assert_success capture
    assert_match %r{Request successfully processed}, capture.message
  end

  def test_successful_partial_refund
    @options[:description] = __method__
    purchase = @gateway.purchase(@amount, @valid_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount-1, purchase.authorization)
    assert_success refund
    assert_match %r{Request successfully processed}, refund.message
  end

  def test_successful_verify
    @options[:description] = __method__
    response = @gateway.verify(@valid_card, @options)
    assert_success response
    assert_match %r{Request successfully processed}, response.message
  end

# ****************************************** FAILURE TESTS ******************************************

  def test_failed_purchase
    @options[:description] = __method__
    response = @gateway.purchase(@amount, @invalid_card, @options)
    assert_failure response
    assert_match %r{invalid creditcard}, response.message
  end

  def test_failed_authorize
    @options[:description] = __method__
    response = @gateway.authorize(@amount, @invalid_card, @options)
    assert_failure response
    assert_match %r{invalid creditcard}, response.message
  end

  def test_failed_capture
    @options[:description] = __method__
    response = @gateway.capture(@amount, @test_wrong_reference_id)
    assert_failure response
    assert_match %r{capture needs at least one successful transaction}, response.message
  end

  def test_failed_refund
    @options[:description] = __method__
    response = @gateway.refund(@amount, @test_wrong_reference_id)
    assert_failure response
    assert_match %r{Invalid payment data}, response.message
  end

  def test_failed_void
    @options[:description] = __method__
    response = @gateway.void(@test_wrong_reference_id, @options)
    assert_failure response
    assert_match %r{reversal needs at least one successful transaction}, response.message
  end

# ************************************** TRANSCRIPT SCRUB ******************************************

  def test_transcript_scrubbing
    assert @gateway.supports_scrubbing?

    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @valid_card)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@valid_card.number, transcript)
    assert_scrubbed(@valid_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:password], transcript)
  end
end
