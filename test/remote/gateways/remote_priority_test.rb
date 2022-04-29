require 'test_helper'

class RemotePriorityTest < Test::Unit::TestCase
  def setup
    @gateway = PriorityGateway.new(fixtures(:priority))

    @amount = 2
    @credit_card = credit_card
    @invalid_credit_card = credit_card('123456')
    @replay_id = rand(100...99999999)
    @options = { billing_address: address }

    @additional_options = {
      is_auth: false,
      should_get_credit_card_level: true,
      should_vault_card: false,
      invoice: '123',
      tax_exempt: true
    }

    @custom_pos_data = {
      pos_data: {
        cardholder_presence: 'NotPresent',
        device_attendance: 'Unknown',
        device_input_capability: 'KeyedOnly',
        device_location: 'Unknown',
        pan_capture_method: 'Manual',
        partial_approval_support: 'Supported',
        pin_capture_capability: 'Twelve'
      }
    }

    @purchases_data = {
      purchases: [
        {
          line_item_id: 79402,
          name: 'Book',
          description: 'The Elements of Style',
          quantity: 1,
          unit_price: 1.23,
          discount_amount: 0,
          extended_amount: '1.23',
          discount_rate: 0,
          tax_amount: 1
        },
        {
          line_item_id: 79403,
          name: 'Cat Poster',
          description: 'A sleeping cat',
          quantity: 1,
          unit_price: '2.34',
          discount_amount: 0,
          extended_amount: '2.34',
          discount_rate: 0
        }
      ]
    }
  end

  def test_successful_authorize
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Approved or completed successfully', response.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @invalid_credit_card, @options)
    assert_failure response
    assert_equal 'Invalid card number', response.message
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Approved or completed successfully', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @invalid_credit_card, @options)
    assert_failure response
    assert_equal 'Invalid card number', response.message
  end

  def test_failed_purchase_missing_card_month
    card_without_month = credit_card('4242424242424242', month: '')
    response = @gateway.purchase(@amount, card_without_month, @options)

    assert_failure response
    assert_equal 'ValidationError', response.error_code
    assert_equal 'Missing expiration month and / or year', response.message
  end

  def test_failed_purchase_missing_card_verification_number
    card_without_cvv = credit_card('4242424242424242', verification_value: '')
    response = @gateway.purchase(@amount, card_without_cvv, @options)

    assert_failure response
    assert_equal 'CVV is required based on merchant fraud settings', response.message
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    capture = @gateway.capture(@amount, auth.authorization, @options)
    assert_success capture
    assert_equal 'Approved', capture.message
  end

  def test_failed_capture
    capture = @gateway.capture(@amount, 'bogus_authorization', @options)
    assert_failure capture
    assert_equal 'Original Transaction Not Found', capture.message
  end

  def test_successful_purchase_with_shipping_data
    options_with_shipping = @options.merge({ ship_to_country: 'USA', ship_to_zip: 27703, ship_amount: 0.01 })
    response = @gateway.purchase(@amount, @credit_card, options_with_shipping)

    assert_success response
    assert_equal 'Approved or completed successfully', response.message
  end

  def test_successful_purchase_with_purchases_data
    options_with_purchases = @options.merge(@purchases_data)
    response = @gateway.purchase(@amount, @credit_card, options_with_purchases)

    assert_success response
    assert_equal response.params['purchases'].first['name'], @purchases_data[:purchases].first[:name]
    assert_equal response.params['purchases'].last['name'], @purchases_data[:purchases].last[:name]
    assert_equal 'Approved or completed successfully', response.message
  end

  def test_successful_purchase_with_custom_pos_data
    options_with_custom_pos_data = @options.merge(@custom_pos_data)
    response = @gateway.purchase(@amount, @credit_card, options_with_custom_pos_data)

    assert_success response
    assert_equal 'Approved or completed successfully', response.message
  end

  def test_successful_purchase_with_additional_options
    options = @options.merge(@additional_options)
    response = @gateway.purchase(@amount, @credit_card, options)

    assert_success response
    assert_equal 'Approved or completed successfully', response.message
  end

  def test_successful_void_with_batch_open
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    # Batch status is by default is set to Open when Sale transaction is created
    batch_check = @gateway.get_payment_status(purchase.params['batchId'])
    assert_equal 'Open', batch_check.message

    void = @gateway.void(purchase.authorization, @options)
    assert_success void
    assert_equal 'Success', void.message
  end

  def test_successful_void_after_closing_batch
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    # Manually close open batch; resulting status should be 'Pending'
    @gateway.close_batch(purchase.params['batchId'])
    payment_status = @gateway.get_payment_status(purchase.params['batchId'])
    assert_equal 'Pending', payment_status.message

    void = @gateway.void(purchase.authorization, @options)
    assert_success void
    assert_equal 'Success', void.message
  end

  def test_failed_void
    bogus_transaction_id = '123456'
    assert void = @gateway.void(bogus_transaction_id, @options)

    assert_failure void
    assert_equal 'Unauthorized', void.error_code
    assert_equal 'Original Payment Not Found Or You Do Not Have Access.', void.message
  end

  def test_successful_refund_with_open_batch
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    batch_check = @gateway.get_payment_status(purchase.params['batchId'])
    assert_equal 'Open', batch_check.message

    refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
    assert_equal 'Approved or completed successfully', refund.message
  end

  def test_successful_refund_after_closing_batch
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    # Manually close open batch; resulting status should be 'Pending'
    @gateway.close_batch(purchase.params['batchId'])
    payment_status = @gateway.get_payment_status(purchase.params['batchId'])
    assert_equal 'Pending', payment_status.message

    refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
    assert_equal 'Approved or completed successfully', refund.message
  end

  def test_successful_get_payment_status
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    batch_check = @gateway.get_payment_status(response.params['batchId'])

    assert_success batch_check
    assert_equal 'Open', batch_check.message
  end

  def test_failed_get_payment_status
    batch_check = @gateway.get_payment_status(123456)

    assert_failure batch_check
    assert_equal 'Invalid JSON response', batch_check.params['message'][0..20]
  end

  def test_successful_verify
    response = @gateway.verify(credit_card('411111111111111'))
    assert_success response
    assert_match 'JPMORGAN CHASE BANK, N.A.', response.params['bank']['name']
  end

  def test_failed_verify
    response = @gateway.verify(@invalid_credit_card)
    assert_failure response
    assert_match 'No bank information found for bin number', response.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    clean_transcript = @gateway.scrub(transcript)
    assert_scrubbed(@credit_card.number, clean_transcript)
    assert_scrubbed(@credit_card.verification_value.to_s, clean_transcript)
  end

  def test_successful_purchase_with_duplicate_replay_id
    response = @gateway.purchase(@amount, @credit_card, @options.merge(replay_id: @replay_id))

    assert_success response
    assert_equal @replay_id, response.params['replayId']

    duplicate_response = @gateway.purchase(@amount, @credit_card, @options.merge(replay_id: response.params['replayId']))

    assert_success duplicate_response
    assert_equal response.params['id'], duplicate_response.params['id']
  end

  def test_failed_purchase_with_duplicate_replay_id
    response = @gateway.purchase(@amount, @invalid_credit_card, @options.merge(replay_id: @replay_id))
    assert_failure response

    duplicate_response = @gateway.purchase(@amount, @invalid_credit_card, @options.merge(replay_id: response.params['replayId']))
    assert_failure duplicate_response

    assert_equal response.message, duplicate_response.message
    assert_equal response.params['status'], duplicate_response.params['status']

    assert_equal response.params['id'], duplicate_response.params['id']
  end

  def test_successful_purchase_with_unique_replay_id
    first_purchase_response = @gateway.purchase(@amount, @credit_card, @options.merge(replay_id: @replay_id))

    assert_success first_purchase_response
    assert_equal @replay_id, first_purchase_response.params['replayId']

    second_purchase_response = @gateway.purchase(@amount + 1, @credit_card, @options.merge(replay_id: @replay_id + 1))

    assert_success second_purchase_response
    assert_not_equal first_purchase_response.params['id'], second_purchase_response.params['id']
  end

  def test_failed_duplicate_refund
    purchase_response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase_response

    refund_response = @gateway.refund(@amount, purchase_response.authorization)

    assert_success refund_response
    assert_equal 'Approved or completed successfully', refund_response.message

    duplicate_refund_response = @gateway.refund(@amount, purchase_response.authorization)

    assert_failure duplicate_refund_response
    assert_equal 'Payment already refunded', duplicate_refund_response.message
  end

  def test_failed_duplicate_void
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    void = @gateway.void(purchase.authorization)
    assert_success void

    duplicate_void = @gateway.void(purchase.authorization)

    assert_failure duplicate_void
    assert_equal 'Payment already voided.', duplicate_void.message
  end
end
