require 'test_helper'

class RemoteMerchantWarriorTest < Test::Unit::TestCase
  def setup
    @gateway = MerchantWarriorGateway.new(fixtures(:merchant_warrior).merge(test: true))

    @success_amount = 100
    @failure_amount = 205

    @credit_card = credit_card(
      '4564710000000004',
      month: '2',
      year: '29',
      verification_value: '847',
      brand: 'visa'
    )

    @expired_card = credit_card(
      '4564710000000012',
      month: '2',
      year: '05',
      verification_value: '963',
      brand: 'visa'
    )

    @options = {
      billing_address: {
        name: 'Longbob Longsen',
        country: 'AU',
        state: 'Queensland',
        city: 'Brisbane',
        address1: '123 test st',
        zip: '4000'
      },
      description: 'TestProduct'
    }
  end

  def test_successful_authorize
    assert auth = @gateway.authorize(@success_amount, @credit_card, @options)
    assert_success auth
    assert_equal 'Transaction approved', auth.message
    assert_not_nil auth.params['transaction_id']
    assert_equal auth.params['transaction_id'], auth.authorization

    assert capture = @gateway.capture(@success_amount, auth.authorization)
    assert_success capture
    assert_not_nil capture.params['transaction_id']
    assert_equal capture.params['transaction_id'], capture.authorization
    assert_not_equal auth.authorization, capture.authorization
  end

  def test_successful_purchase
    assert purchase = @gateway.purchase(@success_amount, @credit_card, @options)
    assert_success purchase
    assert_equal 'Transaction approved', purchase.message
    assert_not_nil purchase.params['transaction_id']
    assert_equal purchase.params['transaction_id'], purchase.authorization
  end

  def test_failed_purchase
    assert purchase = @gateway.purchase(@success_amount, @expired_card, @options)
    assert_match 'Transaction declined', purchase.message
    assert_failure purchase
    assert_not_nil purchase.params['transaction_id']
    assert_equal purchase.params['transaction_id'], purchase.authorization
  end

  def test_successful_refund
    assert purchase = @gateway.purchase(@success_amount, @credit_card, @options)

    assert refund = @gateway.refund(@success_amount, purchase.authorization)
    assert_success refund
    assert_equal 'Transaction approved', refund.message
  end

  def test_failed_refund
    assert refund = @gateway.refund(@success_amount, 'invalid-transaction-id')
    assert_match %r{MW - 011:Invalid transactionID}, refund.message
    assert_failure refund
  end

  def test_successful_void
    assert purchase = @gateway.purchase(@success_amount, @credit_card, @options)
    assert_success purchase

    assert void = @gateway.void(purchase.authorization, amount: @success_amount)
    assert_success void
    assert_equal 'Transaction approved', void.message
  end

  def test_failed_void
    assert void = @gateway.void('invalid-transaction-id', amount: @success_amount)
    assert_match %r{MW - 011:Invalid transactionID}, void.message
    assert_failure void
  end

  def test_capture_too_much
    assert auth = @gateway.authorize(300, @credit_card, @options)
    assert_success auth
    assert_equal 'Transaction approved', auth.message

    assert capture = @gateway.capture(400, auth.authorization)
    assert_match %r{Capture amount is greater than the transaction amount}, capture.message
    assert_failure capture
  end

  def test_successful_token_purchase
    assert store = @gateway.store(@credit_card)
    assert_equal 'Operation successful', store.message
    assert_success store

    assert purchase = @gateway.purchase(@success_amount, store.authorization, @options)
    assert_equal 'Transaction approved', purchase.message
  end

  def test_token_auth
    assert store = @gateway.store(@credit_card)
    assert_success store

    assert auth = @gateway.authorize(@success_amount, store.authorization, @options)
    assert_success auth
    assert_equal 'Transaction approved', auth.message
    assert_not_nil auth.authorization

    assert capture = @gateway.capture(@success_amount, auth.authorization)
    assert_success capture
  end

  def test_successful_purchase_with_funky_names
    @credit_card.first_name = 'Phillips & Sons'
    @credit_card.last_name = "Other-Things; MW. doesn't like"
    @options[:billing_address][:name] = 'Merchant Warrior wants % alphanumerics'

    assert purchase = @gateway.purchase(@success_amount, @credit_card, @options)
    assert_equal 'Transaction approved', purchase.message
    assert_success purchase
  end

  def test_successful_purchase_with_recurring_flag
    @options[:recurring_flag] = 1
    test_successful_purchase
  end

  def test_successful_authorize_with_recurring_flag
    @options[:recurring_flag] = 1
    test_successful_authorize
  end

  def test_successful_authorize_with_soft_descriptors
    @options[:descriptor_name] = 'FOO*Test'
    @options[:descriptor_city] = 'Melbourne'
    @options[:descriptor_state] = 'VIC'
    test_successful_authorize
  end

  def test_successful_purchase_with_soft_descriptors
    @options[:descriptor_name] = 'FOO*Test'
    @options[:descriptor_city] = 'Melbourne'
    @options[:descriptor_state] = 'VIC'
    test_successful_purchase
  end

  def test_successful_refund_with_soft_descriptors
    @options[:descriptor_name] = 'FOO*Test'
    @options[:descriptor_city] = 'Melbourne'
    @options[:descriptor_state] = 'VIC'
    test_successful_refund
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@success_amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_match(%r{paymentCardCSC\=\[FILTERED\]}, transcript)
    assert_no_match(%r{paymentCardCSC=#{@credit_card.verification_value}}, transcript)
    assert_scrubbed(@gateway.options[:api_passphrase], transcript)
    assert_scrubbed(@gateway.options[:api_key], transcript)
  end

  def test_transcript_scrubbing_store
    transcript = capture_transcript(@gateway) do
      @gateway.store(@credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:api_passphrase], transcript)
    assert_scrubbed(@gateway.options[:api_key], transcript)
  end

  def test_successful_purchase_with_three_ds
    @options[:three_d_secure] = {
      version: '2.2.0',
      cavv: 'e1E3SN0xF1lDp9js723iASu3wrA=',
      eci: '05',
      xid: 'ODUzNTYzOTcwODU5NzY3Qw==',
      enrolled: 'true',
      authentication_response_status: 'Y'
    }

    assert response = @gateway.purchase(@success_amount, @credit_card, @options)
    assert_success response
    assert_equal 'Transaction approved', response.message
  end

  def test_successful_purchase_with_three_ds_transaction_id
    @options[:three_d_secure] = {
      version: '2.2.0',
      cavv: 'e1E3SN0xF1lDp9js723iASu3wrA=',
      eci: '05',
      ds_transaction_id: 'ODUzNTYzOTcwODU5NzY3Qw==',
      enrolled: 'true',
      authentication_response_status: 'Y'
    }

    assert response = @gateway.purchase(@success_amount, @credit_card, @options)
    assert_success response
    assert_equal 'Transaction approved', response.message
  end
end
