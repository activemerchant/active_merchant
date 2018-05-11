require 'test_helper'

class PaypalTest < Test::Unit::TestCase
  def setup
    @gateway = PaypalGateway.new(fixtures(:paypal_signature))

    @credit_card = credit_card("4381258770269608") # Use a generated CC from the paypal Sandbox
    @declined_card = credit_card('234234234234')

    @params = {
      :order_id => generate_unique_id,
      :email => 'buyer@jadedpallet.com',
      :billing_address => { :name => 'Longbob Longsen',
                    :address1 => '4321 Penny Lane',
                    :city => 'Jonsetown',
                    :state => 'NC',
                    :country => 'US',
                    :zip => '23456'
                  } ,
      :description => 'Stuff that you purchased, yo!',
      :ip => '10.0.0.1'
    }

    @amount = 100

    # test re-authorization, auth-id must be more than 3 days old.
    # each auth-id can only be reauthorized and tested once.
    # leave it commented if you don't want to test reauthorization.
    #
    #@three_days_old_auth_id  = "9J780651TU4465545"
    #@three_days_old_auth_id2 = "62503445A3738160X"
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @params)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:login], transcript)
    assert_scrubbed(@gateway.options[:password], transcript)
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @params)
    assert_success response
    assert response.params['transaction_id']
  end

  def test_successful_purchase_sans_cvv
    @credit_card.verification_value = nil
    response = @gateway.purchase(@amount, @credit_card, @params)
    assert_success response
    assert response.params['transaction_id']
  end

  def test_successful_purchase_with_descriptors
    response = @gateway.purchase(@amount, @credit_card, @params.merge(soft_descriptor: "Active Merchant TXN", soft_descriptor_city: "800-883-3931"))
    assert_success response
    assert response.params['transaction_id']
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @params)
    assert_failure response
    assert_nil response.params['transaction_id']
  end

  def test_successful_authorization
    response = @gateway.authorize(@amount, @credit_card, @params)
    assert_success response
    assert response.params['transaction_id']
    assert_equal '1.00', response.params['amount']
    assert_equal 'USD', response.params['amount_currency_id']
  end

  def test_failed_authorization
    response = @gateway.authorize(@amount, @declined_card, @params)
    assert_failure response
    assert_nil response.params['transaction_id']
  end

  def test_successful_reauthorization
    return if not @three_days_old_auth_id
    auth = @gateway.reauthorize(1000, @three_days_old_auth_id)
    assert_success auth
    assert auth.authorization

    response = @gateway.capture(1000, auth.authorization)
    assert_success response
    assert response.params['transaction_id']
    assert_equal '10.00', response.params['gross_amount']
    assert_equal 'USD', response.params['gross_amount_currency_id']
  end

  def test_failed_reauthorization
    return if not @three_days_old_auth_id2  # was authed for $10, attempt $20
    auth = @gateway.reauthorize(2000, @three_days_old_auth_id2)
    assert_false auth?
    assert !auth.authorization
  end

  def test_successful_capture
    auth = @gateway.authorize(@amount, @credit_card, @params)
    assert_success auth
    response = @gateway.capture(@amount, auth.authorization)
    assert_success response
    assert response.params['transaction_id']
    assert_equal '1.00', response.params['gross_amount']
    assert_equal 'USD', response.params['gross_amount_currency_id']
  end

  def test_successful_incomplete_captures
    auth = @gateway.authorize(100, @credit_card, @params)
    assert_success auth
    response = @gateway.capture(60, auth.authorization, {:complete_type => "NotComplete"})
    assert_success response
    assert response.params['transaction_id']
    assert_equal '0.60', response.params['gross_amount']
    response_2 = @gateway.capture(40, auth.authorization)
    assert_success response_2
    assert response_2.params['transaction_id']
    assert_equal '0.40', response_2.params['gross_amount']
  end

  def test_successful_capture_updating_the_invoice_id
    auth = @gateway.authorize(@amount, @credit_card, @params)
    assert_success auth
    response = @gateway.capture(@amount, auth.authorization, :order_id => "NEWID#{generate_unique_id}")
    assert_success response
    assert response.params['transaction_id']
    assert_equal '1.00', response.params['gross_amount']
    assert_equal 'USD', response.params['gross_amount_currency_id']
  end

  def test_successful_voiding
    auth = @gateway.authorize(@amount, @credit_card, @params)
    assert_success auth
    response = @gateway.void(auth.authorization)
    assert_success response
  end

  def test_purchase_and_full_credit
    purchase = @gateway.purchase(@amount, @credit_card, @params)
    assert_success purchase

    credit = @gateway.refund(@amount, purchase.authorization, :note => 'Sorry')
    assert_success credit
    assert credit.test?
    assert_equal 'USD',  credit.params['net_refund_amount_currency_id']
    assert_equal '0.97', credit.params['net_refund_amount']
    assert_equal 'USD',  credit.params['gross_refund_amount_currency_id']
    assert_equal '1.00', credit.params['gross_refund_amount']
    assert_equal 'USD',  credit.params['fee_refund_amount_currency_id']
    assert_equal '0.03', credit.params['fee_refund_amount'] # As of August 2010, PayPal keeps the flat fee ($0.30)
  end

  def test_failed_voiding
    response = @gateway.void('foo')
    assert_failure response
  end

  def test_successful_verify
    assert response = @gateway.verify(@credit_card, @params)
    assert_success response
    assert_equal "0.00", response.params['amount']
    assert_match %r{This card authorization verification is not a payment transaction}, response.message
  end

  def test_failed_verify
    assert response = @gateway.verify(@declined_card, @params)
    assert_failure response
    assert_match %r{This transaction cannot be processed}, response.message
  end

  def test_successful_verify_non_visa_mc
    amex_card = credit_card('371449635398431', brand: nil, verification_value: '1234')
    assert response = @gateway.verify(amex_card, @params)
    assert_success response
    assert_equal "1.00", response.params['amount']
    assert_match %r{Success}, response.message
    assert_success response.responses.last, "The void should succeed"
  end

  def test_successful_transfer
    response = @gateway.purchase(@amount, @credit_card, @params)
    assert_success response

    response = @gateway.transfer(@amount, 'joe@example.com', :subject => 'Your money', :note => 'Thanks for taking care of that')
    assert_success response
  end

  def test_failed_transfer
     # paypal allows a max transfer of $10,000
    response = @gateway.transfer(1000001, 'joe@example.com')
    assert_failure response
  end

  def test_successful_multiple_transfer
    response = @gateway.purchase(900, @credit_card, @params)
    assert_success response

    response = @gateway.transfer([@amount, 'joe@example.com'],
      [600, 'jane@example.com', {:note => 'Thanks for taking care of that'}],
      :subject => 'Your money')
    assert_success response
  end

  def test_failed_multiple_transfer
    response = @gateway.purchase(25100, @credit_card, @params)
    assert_success response

    # You can only include up to 250 recipients
    recipients = (1..251).collect {|i| [100, "person#{i}@example.com"]}
    response = @gateway.transfer(*recipients)
    assert_failure response
  end

  def test_successful_email_transfer
    response = @gateway.purchase(@amount, @credit_card, @params)
    assert_success response

    response = @gateway.transfer([@amount, 'joe@example.com'], :receiver_type => 'EmailAddress', :subject => 'Your money', :note => 'Thanks for taking care of that')
    assert_success response
  end

  def test_successful_userid_transfer
    response = @gateway.purchase(@amount, @credit_card, @params)
    assert_success response

    response = @gateway.transfer([@amount, '4ET96X3PQEN8H'], :receiver_type => 'UserID', :subject => 'Your money', :note => 'Thanks for taking care of that')
    assert_success response
  end

  def test_failed_userid_transfer
    response = @gateway.purchase(@amount, @credit_card, @params)
    assert_success response

    response = @gateway.transfer([@amount, 'joe@example.com'], :receiver_type => 'UserID', :subject => 'Your money', :note => 'Thanks for taking care of that')
    assert_failure response
  end

  # Makes a purchase then makes another purchase adding $1.00 using just a reference id (transaction id)
  def test_successful_referenced_id_purchase
    response = @gateway.purchase(@amount, @credit_card, @params)
    assert_success response
    id_for_reference = response.params['transaction_id']

    @params.delete(:order_id)
    response2 = @gateway.purchase(@amount + 100, id_for_reference, @params)
    assert_success response2
  end

end
