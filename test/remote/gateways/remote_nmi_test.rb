require 'test_helper'

class RemoteNmiTest < Test::Unit::TestCase
  def setup
    @gateway = NmiGateway.new(fixtures(:nmi))
    @amount = Random.rand(100...1000)
    @credit_card = credit_card('4111111111111111', verification_value: 917)
    @check = check(
      :routing_number => '123123123',
      :account_number => '123123123'
    )
    @apple_pay_card = network_tokenization_credit_card('4111111111111111',
      :payment_cryptogram => 'EHuWW9PiBkWvqE5juRwDzAUFBAk=',
      :month              => '01',
      :year               => '2024',
      :source             => :apple_pay,
      :eci                => '5',
      :transaction_id     => '123456789'
    )
    @options = {
      :order_id => generate_unique_id,
      :billing_address => address,
      :description => 'Store purchase'
    }
    @level3_options = {
       tax: 5.25, shipping: 10.51, ponumber: 1002
    }
  end

  def test_invalid_login
    @gateway = NmiGateway.new(login: 'invalid', password: 'no')
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Authentication Failed', response.message
  end

  def test_successful_purchase
    options = @options.merge(@level3_options)

    assert response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert response.test?
    assert_equal 'Succeeded', response.message
    assert response.authorization
  end

  def test_successful_purchase_sans_cvv
    @credit_card.verification_value = nil
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert response.test?
    assert_equal 'Succeeded', response.message
    assert response.authorization
  end

  def test_failed_purchase
    assert response = @gateway.purchase(99, @credit_card, @options)
    assert_failure response
    assert response.test?
    assert_equal 'DECLINE', response.message
  end

  def test_successful_purchase_with_echeck
    assert response = @gateway.purchase(@amount, @check, @options)
    assert_success response
    assert response.test?
    assert_equal 'Succeeded', response.message
    assert response.authorization
  end

  def test_failed_purchase_with_echeck
    assert response = @gateway.purchase(99, @check, @options)
    assert_failure response
    assert response.test?
    assert_equal 'FAILED', response.message
  end

  def test_successful_purchase_with_apple_pay_card
    assert @gateway.supports_network_tokenization?
    assert response = @gateway.purchase(@amount, @apple_pay_card, @options)
    assert_success response
    assert response.test?
    assert_equal 'Succeeded', response.message
    assert response.authorization
  end

  def test_failed_purchase_with_apple_pay_card
    assert response = @gateway.purchase(99, @apple_pay_card, @options)
    assert_failure response
    assert response.test?
    assert_equal 'DECLINE', response.message
  end

  def test_successful_purchase_with_additional_options
    options = @options.merge({
      customer_id: '234',
      vendor_id: '456',
      recurring: true,
    })
    assert response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert response.test?
    assert_equal 'Succeeded', response.message
    assert response.authorization
  end

  def test_successful_authorization
    options = @options.merge(@level3_options)

    assert response = @gateway.authorize(@amount, @credit_card, options)
    assert_success response
    assert_equal 'Succeeded', response.message
    assert response.authorization
  end

  def test_failed_authorization
    assert response = @gateway.authorize(99, @credit_card, @options)
    assert_failure response
    assert response.test?
    assert_equal 'DECLINE', response.message
  end

  def test_authorization_and_capture
    assert authorization = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorization

    assert capture = @gateway.capture(@amount, authorization.authorization)
    assert_success capture
    assert_equal 'Succeeded', capture.message
  end

  def test_failed_capture
    assert capture = @gateway.capture(@amount, 'badauth')
    assert_failure capture
  end

  def test_authorization_and_void
    assert authorization = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorization

    assert void = @gateway.void(authorization.authorization)
    assert_success void
    assert_equal 'Succeeded', void.message
  end

  def test_failed_void
    assert void = @gateway.void('badauth')
    assert_failure void
  end

  def test_successful_void_with_echeck
    assert response = @gateway.purchase(@amount, @check, @options)
    assert_success response

    assert response = @gateway.void(response.authorization)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_successful_refund
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert response = @gateway.refund(@amount, response.authorization)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_failed_refund
    assert response = @gateway.refund(@amount, 'badauth')
    assert_failure response
  end

  def test_successful_refund_with_echeck
    assert response = @gateway.purchase(@amount, @check, @options)
    assert_success response

    assert response = @gateway.refund(@amount, response.authorization)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_successful_credit
    options = @options.merge(@level3_options)

    response = @gateway.credit(@amount, @credit_card, options)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_failed_credit
    card = credit_card(year: 2010)
    response = @gateway.credit(@amount, card, @options)
    assert_failure response
  end

  def test_successful_verify
    options = @options.merge(@level3_options)

    response = @gateway.verify(@credit_card, options)
    assert_success response
    assert_match 'Succeeded', response.message
  end

  def test_failed_verify
    card = credit_card(year: 2010)
    response = @gateway.verify(card, @options)
    assert_failure response
    assert_match 'Invalid Credit Card', response.message
  end

  def test_successful_store
    response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal 'Succeeded', response.message
    assert response.authorization.include?(response.params['customer_vault_id'])
  end

  def test_failed_store
    card = credit_card(year: 2010)
    response = @gateway.store(card, @options)
    assert_failure response
  end

  def test_successful_store_with_echeck
    response = @gateway.store(@check, @options)
    assert_success response
    assert_equal 'Succeeded', response.message
    assert response.authorization.include?(response.params['customer_vault_id'])
  end

  def test_successful_store_and_purchase
    vault_id = @gateway.store(@credit_card, @options).authorization
    purchase = @gateway.purchase(@amount, vault_id, @options)
    assert_success purchase
    assert_equal 'Succeeded', purchase.message
  end

  def test_successful_store_and_auth
    vault_id = @gateway.store(@credit_card, @options).authorization
    auth = @gateway.authorize(@amount, vault_id, @options)
    assert_success auth
    assert_equal 'Succeeded', auth.message
  end

  def test_successful_store_and_credit
    vault_id = @gateway.store(@credit_card, @options).authorization
    credit = @gateway.credit(@amount, vault_id, @options)
    assert_success credit
    assert_equal 'Succeeded', credit.message
  end

  def test_merchant_defined_fields
    (1..20).each { |e| @options["merchant_defined_field_#{e}".to_sym] = "value #{e}" }
    assert_success @gateway.purchase(@amount, @credit_card, @options)
  end

  def test_verify_credentials
    assert @gateway.verify_credentials

    gateway = NmiGateway.new(login: 'unknown', password: 'unknown')
    assert !gateway.verify_credentials
    gateway = NmiGateway.new(login: fixtures(:nmi)[:login], password: 'unknown')
    assert !gateway.verify_credentials
  end

  def test_purchase_using_stored_credential_recurring_cit
    initial_options = stored_credential_options(:cardholder, :recurring, :initial)
    assert purchase = @gateway.purchase(@amount, @credit_card, initial_options)
    assert_success purchase
    assert network_transaction_id = purchase.params['transactionid']

    used_options = stored_credential_options(:recurring, :cardholder, id: network_transaction_id)
    assert purchase = @gateway.purchase(@amount, @credit_card, used_options)
    assert_success purchase
  end

  def test_purchase_using_stored_credential_recurring_mit
    initial_options = stored_credential_options(:merchant, :recurring, :initial)
    assert purchase = @gateway.purchase(@amount, @credit_card, initial_options)
    assert_success purchase
    assert network_transaction_id = purchase.params['transactionid']

    used_options = stored_credential_options(:merchant, :recurring, id: network_transaction_id)
    assert purchase = @gateway.purchase(@amount, @credit_card, used_options)
    assert_success purchase
  end

  def test_purchase_using_stored_credential_installment_cit
    initial_options = stored_credential_options(:cardholder, :installment, :initial)
    assert purchase = @gateway.purchase(@amount, @credit_card, initial_options)
    assert_success purchase
    assert network_transaction_id = purchase.params['transactionid']

    used_options = stored_credential_options(:cardholder, :installment, id: network_transaction_id)
    assert purchase = @gateway.purchase(@amount, @credit_card, used_options)
    assert_success purchase
  end

  def test_purchase_using_stored_credential_installment_mit
    initial_options = stored_credential_options(:merchant, :installment, :initial)
    assert purchase = @gateway.purchase(@amount, @credit_card, initial_options)
    assert_success purchase
    assert network_transaction_id = purchase.params['transactionid']

    used_options = stored_credential_options(:merchant, :installment, id: network_transaction_id)
    assert purchase = @gateway.purchase(@amount, @credit_card, used_options)
    assert_success purchase
  end

  def test_purchase_using_stored_credential_unscheduled_cit
    initial_options = stored_credential_options(:cardholder, :unscheduled, :initial)
    assert purchase = @gateway.purchase(@amount, @credit_card, initial_options)
    assert_success purchase
    assert network_transaction_id = purchase.params['transactionid']

    used_options = stored_credential_options(:cardholder, :unscheduled, id: network_transaction_id)
    assert purchase = @gateway.purchase(@amount, @credit_card, used_options)
    assert_success purchase
  end

  def test_purchase_using_stored_credential_unscheduled_mit
    initial_options = stored_credential_options(:merchant, :unscheduled, :initial)
    assert purchase = @gateway.purchase(@amount, @credit_card, initial_options)
    assert_success purchase
    assert network_transaction_id = purchase.params['transactionid']

    used_options = stored_credential_options(:merchant, :unscheduled, id: network_transaction_id)
    assert purchase = @gateway.purchase(@amount, @credit_card, used_options)
    assert_success purchase
  end

  def test_authorize_and_capture_with_stored_credential
    initial_options = stored_credential_options(:cardholder, :recurring, :initial)
    assert authorization = @gateway.authorize(@amount, @credit_card, initial_options)
    assert_success authorization
    assert network_transaction_id = authorization.params['transactionid']

    assert capture = @gateway.capture(@amount, authorization.authorization)
    assert_success capture

    used_options = stored_credential_options(:cardholder, :recurring, id: network_transaction_id)
    assert authorization = @gateway.authorize(@amount, @credit_card, used_options)
    assert_success authorization
    assert @gateway.capture(@amount, authorization.authorization)
  end

  def test_card_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    clean_transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, clean_transcript)
    assert_cvv_scrubbed(clean_transcript)
    assert_password_scrubbed(clean_transcript)
  end

  def test_check_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @check, @options)
    end
    clean_transcript = @gateway.scrub(transcript)

    assert_scrubbed(@check.account_number, clean_transcript)
    assert_scrubbed(@check.routing_number, clean_transcript)
    assert_password_scrubbed(clean_transcript)
  end

  def test_network_tokenization_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @apple_pay_card, @options)
    end
    clean_transcript = @gateway.scrub(transcript)

    assert_scrubbed(@apple_pay_card.number, clean_transcript)
    assert_scrubbed(@apple_pay_card.payment_cryptogram, clean_transcript)
    assert_password_scrubbed(clean_transcript)
  end

  private

  # "password=password is filtered, but can't be tested via normal
  # `assert_scrubbed` b/c of key match"
  def assert_password_scrubbed(transcript)
    assert_match(/password=\[FILTERED\]/, transcript)
  end

  # Because the cvv is a simple three digit number, sometimes there are random
  # failures using `assert_scrubbed` because of natural collisions with a
  # substring within orderid in transcript; e.g.
  #
  #   Expected the value to be scrubbed out of the transcript.
  #   </917/> was expected to not match
  #   <"opening connection to secure.nmi.com:443...\nopened\nstarting SSL for secure.nmi.com:443...\nSSL established\n<- \"POST /api/transact.php HTTP/1.1\\r\\nContent-Type: application/x-www-form-urlencoded;charset=UTF-8\\r\\nConnection: close\\r\\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\\r\\nAccept: */*\\r\\nUser-Agent: Ruby\\r\\nHost: secure.nmi.com\\r\\nContent-Length: 394\\r\\n\\r\\n\"\n<- \"amount=7.96&orderid=9bb4c3bf6fbb26b91796ae9442cb1941&orderdescription=Store+purchase&currency=USD&payment=creditcard&firstname=Longbob&lastname=Longsen&ccnumber=[FILTERED]&cvv=[FILTERED]&ccexp=0920&email=&ipaddress=&customer_id=&company=Widgets+Inc&address1=456+My+Street&address2=Apt+1&city=Ottawa&state=ON&country=CA&zip=K1C2N6&phone=%28555%29555-5555&type=sale&username=demo&password=[FILTERED]\"\n-> \"HTTP/1.1 200 OK\\r\\n\"\n-> \"Date: Wed, 12 Jun 2019 21:10:29 GMT\\r\\n\"\n-> \"Server: Apache\\r\\n\"\n-> \"Content-Length: 169\\r\\n\"\n-> \"Connection: close\\r\\n\"\n-> \"Content-Type: text/html; charset=UTF-8\\r\\n\"\n-> \"\\r\\n\"\nreading 169 bytes...\n-> \"response=1&responsetext=SUCCESS&authcode=123456&transactionid=4743046890&avsresponse=N&cvvresponse=N&orderid=9bb4c3bf6fbb26b91796ae9442cb1941&type=sale&response_code=100\"\nread 169 bytes\nConn close\n">.
  def assert_cvv_scrubbed(transcript)
    assert_match(/cvv=\[FILTERED\]/, transcript)
  end

  def stored_credential_options(*args, id: nil)
    @options.merge(order_id: generate_unique_id,
                   stored_credential: stored_credential(*args, id: id))
  end
end
