require 'test_helper'

class RemoteFatZebraTest < Test::Unit::TestCase
  def setup
    @gateway = FatZebraGateway.new(fixtures(:fat_zebra))

    @amount = 100
    @credit_card = credit_card('5123456789012346')
    @declined_card = credit_card('4557012345678902')

    @options = {
      :order_id => rand(100000).to_s,
      :ip => "123.1.2.3"
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_successful_multi_currency_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(:currency => 'USD'))
    assert_success response
    assert_equal 'Approved', response.message
    assert_equal 'USD', response.params['response']['currency']
  end

  def test_unsuccessful_multi_currency_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(:currency => 'XYZ'))
    assert_failure response
    assert_match /Currency XYZ is not valid for this merchant/, response.message
  end

  def test_successful_purchase_sans_cvv
    @credit_card.verification_value = nil
    assert response = @gateway.purchase(@amount, @credit_card, recurring: true)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_failed_purchase_sans_cvv
    @credit_card.verification_value = nil
    assert response = @gateway.purchase(@amount, @credit_card)
    assert_failure response
    assert_equal 'CVV is required', response.message
  end

  def test_successful_purchase_with_no_options
    assert response = @gateway.purchase(@amount, @credit_card)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_successful_authorize_and_capture
    assert auth_response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth_response
    assert_equal 'Approved', auth_response.message

    assert capture_response = @gateway.capture(@amount, auth_response.authorization, @options)
    assert_success capture_response
    assert_equal 'Approved', capture_response.message
  end

  def test_multi_currency_authorize_and_capture
    assert auth_response = @gateway.authorize(@amount, @credit_card, @options.merge(:currency => 'USD'))
    assert_success auth_response
    assert_equal 'Approved', auth_response.message
    assert_equal 'USD', auth_response.params['response']['currency']

    assert capture_response = @gateway.capture(@amount, auth_response.authorization, @options.merge(:currency => 'USD'))
    assert_success capture_response
    assert_equal 'Approved', capture_response.message
    assert_equal 'USD', capture_response.params['response']['currency']
  end

  def test_successful_partial_capture
    assert auth_response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth_response
    assert_equal 'Approved', auth_response.message

    assert capture_response = @gateway.capture(@amount - 1, auth_response.authorization, @options)
    assert_success capture_response
    assert_equal 'Approved', capture_response.message
    assert_equal @amount - 1, capture_response.params['response']['captured_amount']
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Declined', response.message
  end

  def test_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)

    assert response = @gateway.refund(@amount, purchase.authorization, @options)
    assert_success response
    assert_match %r{Approved}, response.message
  end

  def test_invalid_refund
    @gateway.purchase(@amount, @credit_card, @options)

    assert response = @gateway.refund(@amount, nil, @options)
    assert_failure response
    assert_match %r{Invalid credit card for unmatched refund}, response.message
  end

  def test_store
    assert card = @gateway.store(@credit_card)

    assert_success card
    assert_false card.authorization.nil?
  end

  def test_purchase_with_token
    assert card = @gateway.store(@credit_card)
    assert purchase = @gateway.purchase(@amount, card.authorization, @options.merge(:cvv => 123))
    assert_success purchase
  end

  def test_successful_purchase_with_descriptor
    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(:merchant => 'Merchant', :merchant_location => 'Location'))
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_successful_purchase_with_3DS_information
    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(:cavv => 'MDRjN2MxZTAxYjllNTBkNmM2MTA=', :xid => 'MGVmMmNlMzI4NjAyOWU2ZDgwNTQ=', :sli => '05'))
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_failed_purchase_with_incomplete_3DS_information
    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(:cavv => 'MDRjN2MxZTAxYjllNTBkNmM2MTA=', :sli => '05'))
    assert_failure response
    assert_match %r{Extra/xid is required for SLI 05}, response.message
  end

  def test_invalid_login
    gateway = FatZebraGateway.new(
                :username => 'invalid',
                :token => 'wrongtoken'
              )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Invalid Login', response.message
  end
end
