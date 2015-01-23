require 'test_helper'

class RemoteMondidoTest < Test::Unit::TestCase

  def setup
    start_params = fixtures(:mondido)

    # Gateway without Public Key Crypto
    @gateway = MondidoGateway.new(start_params)

    @amount = 1000 # $ 10.00
    @credit_card = credit_card('4111111111111111', { verification_value: '200' })
    @declined_card = credit_card('4111111111111111', { verification_value: '201' })
    @cvv_invalid_card = credit_card('4111111111111111', { verification_value: '202' })
    @expired_card = credit_card('4111111111111111', { verification_value: '203' })
    @declined_stored_card = @declined_card

    @options = { test: true }
    @store_options = {
        :test => true,
        :currency => 'sek',
    }

    # The @base_order_id and @counter are for test purposes
    # More precisely, the payment_ref value generation as
    # could not exist more than one transaction using the same payment_ref value
    @counter = 1
    @base_order_id = (200000000)
  end

  ## HELPERS
  #

  def generate_random_number
    rnumber = (@base_order_id + @counter).to_s + Time.now.strftime("%s%L")
    @counter += 1
    return rnumber
  end

  def generate_stored_card
    "54c23baa241"
  end

  def generate_customer_ref_or_id(existing_customer)
    (existing_customer ? 24873 : generate_random_number)
  end

  def generate_order_id
    generate_random_number
  end

  def generate_webhook
      {
        "trigger" => "payment_success",
        "email" => "test@mondido.com"
      }.to_json
  end

  def generate_metadata
    {
      "products" => [
      {
        "id" => "1",
        "name" => "Nice Shoe",
        "price" => "100.00",
        "qty" => "1",
        "url" => "http://mondido.com/product/1"
      }
      ],
      "user" => {
        "email" => "test@mondido.com"
      }
    }.to_json
  end

  def store_response(encryption, existing_customer, success)
    gateway = encryption ? nil : @gateway   
    card = success ? @credit_card : @declined_card

    if existing_customer
      @store_options[:customer] = generate_customer_ref_or_id(existing_customer)
    end

    return gateway.store(card, @store_options)
  end

  def store_successful(encryption, existing_customer)
    response = store_response(encryption, existing_customer, true)
    assert_success response
    assert_equal "SEK", response.params["currency"]
    assert_equal "active", response.params["status"]
  end

  def store_failure(encryption, existing_customer)
    response = store_response(encryption, existing_customer, false)
    assert_failure response
    assert_equal "errors.payment.declined", response.params["name"]
  end

  def purchase_response(new_options, encryption, authorize, stored_card, success)
    gateway = encryption ? nil : @gateway
    card = stored_card ? generate_stored_card : @credit_card
    declined_card = stored_card ? @declined_stored_card : @declined_card

    return (authorize ?
      gateway.authorize(@amount, (success ? card : declined_card), new_options)
        :
      gateway.purchase(@amount, (success ? card : declined_card), new_options)
    )
  end

  def purchase_successful(new_options, encryption, authorize, stored_card, customer=nil)
    response = purchase_response(new_options, encryption, authorize, stored_card, true)

    assert_success response
    assert_equal new_options[:order_id], response.params["payment_ref"]
    assert_equal ( authorize ? "authorized" : "approved" ), response.params["status"]
    assert_equal ( stored_card ? "stored_card" : "credit_card" ), response.params["transaction_type"]

    if customer.nil? && stored_card==false
      assert_equal nil, response.params["customer"]
    else
      assert response.params["customer"]["id"].is_a?(Integer)
    end
  end

  def purchase_failure(new_options, encryption, authorize, stored_card)
    response = purchase_response(new_options, encryption, authorize, stored_card, false)

    assert_failure response
    assert_equal "errors.payment.declined", response.params["name"]
  end

  def format_amount(amount)
    amount.to_s[0..-3].to_i.round(1).to_s
  end

  # CAUTION: You may get lost in the weeds to understand how these tests are structured.
  # Please access the documentation of MondidoGateway and look for the "Remote Tests
  # Coverage" to see the big picture. Do it before scrolling down.
  #
  # 1. Scrubbing
  # 2. Initialize/Login
  # 3. Purchase
  # 4. Authorize
  # 5. Capture
  # 6. Refund
  # 7. Void
  # 8. Verify
  # 9. Store Card
  # 10. Unstore Card
  # 11. Extendability, Locale

  ## 1. Scrubbing
  #
  #def test_dump_transcript
    #skip("Transcript scrubbing for this gateway has been tested.")

    # This test will run a purchase transaction on your gateway
    # and dump a transcript of the HTTP conversation so that
    # you can use that transcript as a reference while
    # implementing your scrubbing logic
    #dump_transcript_and_fail(@gateway, @amount, @credit_card, @options.merge({
    #    :order_id => generate_order_id
    #}))
  #end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options.merge({
        :order_id => generate_order_id
      }))
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed("card_cvv=#{@credit_card.verification_value}", transcript)
    assert_scrubbed(@gateway.options[:api_token], transcript)
    assert_scrubbed(@gateway.options[:hash_secret], transcript)

    b64_value = Base64.encode64(
      fixtures(:mondido)[:merchant_id].to_s + ":" + fixtures(:mondido)[:api_token]
    ).strip
    assert_scrubbed("Authorization: Basic #{b64_value}", transcript)
  end

  ## 2. Initialize/Login
  #

  def test_invalid_login
    gateway = MondidoGateway.new(
      merchant_id: '',
      api_token: '',
      hash_secret: ''
    )
    response = gateway.purchase(@amount, @credit_card, @options.merge({
        :order_id => generate_order_id
    }))
    assert_failure response
  end

  ## 3. Purchase
  #

  # Without Encryption

  # Without Recurring

  # With Web Hook

  # With Meta Data

  def test_successful_purchase_credit_card_webhook_metadata_valid_customer(encryption=false, authorize=false, stored=false)
    new_options = @options.merge({
      :order_id => generate_order_id,
      :webhook => generate_webhook,
      :metadata => generate_metadata,
      :customer => generate_customer_ref_or_id(true)
    })
    purchase_successful(new_options, encryption, authorize, stored, true)
  end

  def test_successful_purchase_credit_card_webhook_metadata_invalid_customer(encryption=false, authorize=false, stored=false)
    new_options = @options.merge({
      :order_id => generate_order_id,
      :webhook => generate_webhook,
      :metadata => generate_metadata,
      :customer => generate_customer_ref_or_id(false)
    })
    purchase_successful(new_options, encryption, authorize, stored, false)
  end

  def test_successful_purchase_credit_card_webhook_metadata(encryption=false, authorize=false, stored=false)
    new_options = @options.merge({
      :order_id => generate_order_id,
      :webhook => generate_webhook,
      :metadata => generate_metadata
    })
    purchase_successful(new_options, encryption, authorize, stored)
  end

  def test_failed_purchase_credit_card_webhook_metadata(encryption=false, authorize=false, stored=false)
    new_options = @options.merge({
      :order_id => generate_order_id,
      :webhook => generate_webhook,
      :metadata => generate_metadata
    })
    purchase_failure(new_options, encryption, authorize, stored)
  end

  # Without Meta Data

  def test_successful_purchase_credit_card_webhook(encryption=false, authorize=false, stored=false)
    new_options = @options.merge({
      :order_id => generate_order_id,
      :webhook => generate_webhook
    })
    purchase_successful(new_options, encryption, authorize, stored)
  end

  def test_failed_purchase_credit_card_webhook(encryption=false, authorize=false, stored=false)
    new_options = @options.merge({
      :order_id => generate_order_id,
      :webhook => generate_webhook
    })
    purchase_failure(new_options, encryption, authorize, stored)
  end

  # Without Web Hooks

  # With Meta Data

  def test_successful_purchase_credit_card_metadata(encryption=false, authorize=false, stored=false)
    new_options = @options.merge({
      :order_id => generate_order_id,
      :metadata => generate_metadata
    })
    purchase_successful(new_options, encryption, authorize, stored)
  end

  def test_failed_purchase_credit_card_metadata(encryption=false, authorize=false, stored=false)
    new_options = @options.merge({
      :order_id => generate_order_id,
      :metadata => generate_metadata
    })
    purchase_failure(new_options, encryption, authorize, stored)
  end

  # Without Meta Data

  def test_successful_purchase_credit_card(encryption=false, authorize=false, stored=false)
    new_options = @options.merge({
      :order_id => generate_order_id
    })
    purchase_successful(new_options, encryption, authorize, stored)
  end

  def test_failed_purchase_credit_card(encryption=false, authorize=false, stored=false)
    new_options = @options.merge({
      :order_id => generate_order_id
    })
    purchase_failure(new_options, encryption, authorize, stored)
  end

  # With Stored Card
  # With Web Hooks
  # With Meta Data
  # Without Recurring

  def test_successful_purchase_stored_card_webhook_metadata(encryption=false, authorize=false, stored=true)
    test_successful_purchase_credit_card_webhook_metadata(encryption, authorize, stored)
  end

  def test_failed_purchase_stored_card_webhook_metadata(encryption=false, authorize=false, stored=true)
    test_failed_purchase_credit_card_webhook_metadata(encryption, authorize, stored)
  end

  # Without Meta Data

  def test_successful_purchase_stored_card_webhook(encryption=false, authorize=false, stored=true)
    test_successful_purchase_credit_card_webhook(encryption, authorize, stored)
  end

  def test_failed_purchase_stored_card_webhook(encryption=false, authorize=false, stored=true)
    test_failed_purchase_credit_card_webhook(encryption, authorize, stored)
  end

  # Without Web Hooks

  # With Meta Data

  def test_successful_purchase_stored_card_metadata(encryption=false, authorize=false, stored=true)
    test_successful_purchase_credit_card_metadata(encryption, authorize, stored)
  end

  def test_failed_purchase_stored_card_metadata(encryption=false, authorize=false, stored=true)
    test_failed_purchase_credit_card_metadata(encryption, authorize, stored)
  end

  # Without Meta Data

  def test_successful_purchase_stored_card(encryption=false, authorize=false, stored=true)
    test_successful_purchase_credit_card(encryption, authorize, stored)
  end

  def test_failed_purchase_stored_card(encryption=false, authorize=false, stored=true)
    test_failed_purchase_credit_card(encryption, authorize, stored)
  end


  ## 4. Authorize
  #

  # Without Encryption

  # Without Recurring

  # With Web Hook

  # With Meta Data

  def test_successful_authorize_credit_card_webhook_metadata
    test_successful_purchase_credit_card_webhook_metadata(false, true, false)
  end

  def test_failed_authorize_credit_card_webhook_metadata
    test_failed_purchase_credit_card_webhook_metadata(false, true, false)
  end

  # Without Meta Data

  def test_successful_authorize_credit_card_webhook
    test_successful_purchase_credit_card_webhook(false, true, false)
  end

  def test_failed_authorize_credit_card_webhook
    test_failed_purchase_credit_card_webhook(false, true, false)
  end

  # Without Web Hooks

  # With Meta Data

  def test_successful_authorize_credit_card_metadata
    test_successful_purchase_credit_card_metadata(false, true, false)
  end

  def test_failed_authorize_credit_card_metadata
    test_failed_purchase_credit_card_metadata(false, true, false)
  end

  # Without Meta Data

  def test_successful_authorize_credit_card
    test_successful_purchase_credit_card(false, true, false)
  end

  def test_failed_authorize_credit_card
    test_failed_purchase_credit_card(false, true, false)
  end

  # With Stored Card
  # Without Recurring
  # With Web Hooks
  # With Meta Data

  # With Meta Data

  def test_successful_authorize_stored_card_webhook_metadata
    test_successful_purchase_credit_card_webhook_metadata(false, true, true)
  end

  def test_failed_authorize_stored_card_webhook_metadata
    test_failed_purchase_credit_card_webhook_metadata(false, true, true)
  end

  # Without Meta Data

  def test_successful_authorize_stored_card_webhook
    test_successful_purchase_credit_card_webhook(false, true, true)
  end

  def test_failed_authorize_stored_card_webhook
    test_failed_purchase_credit_card_webhook(false, true, true)
  end

  # Without Web Hooks

  # With Meta Data

  def test_successful_authorize_stored_card_metadata
    test_successful_purchase_credit_card_metadata(false, true, true)
  end

  def test_failed_authorize_stored_card_metadata
    test_failed_purchase_credit_card_metadata(false, true, true)
  end

  # Without Meta Data

  def test_successful_authorize_stored_card
    test_successful_purchase_credit_card(false, true, true)
  end

  def test_failed_authorize_stored_card
    test_failed_purchase_credit_card(false, true, true)
  end

  ## 5. Capture
  #

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options.merge({
        :order_id => generate_order_id
    }))
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal "authorized", auth.params["status"]
    assert_equal format_amount(@amount), capture.params["amount"]
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options.merge({
        :order_id => generate_order_id
    }))
    assert_success auth

    assert capture = @gateway.capture(@amount/2, auth.authorization)
    assert_success capture
    assert_equal format_amount(@amount/2), capture.params["amount"]
    assert_equal "authorized", auth.params["status"]
  end

  def test_failed_capture
    response = @gateway.capture(nil, '')
    assert_failure response
    assert_equal "errors.amount.invalid", response.params["name"]
  end

  ## 6. Refund
  #

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options.merge({
        :order_id => generate_order_id
    }))
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization, reason: "Test")
    assert_success refund
    assert_equal format_amount(@amount), purchase.params["amount"]
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options.merge({
        :order_id => generate_order_id
    }))
    assert_success purchase

    assert refund = @gateway.refund(@amount/2, purchase.authorization, reason: "Test")
    assert_equal format_amount(@amount/2), refund.params["amount"]
    assert_success refund
  end

  def test_failed_refund
    response = @gateway.refund(nil, '', reason: "Test")
    assert_failure response
    assert_equal "errors.transaction.not_found", response.params["name"]
  end

  ## 7. Void
  #

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options.merge({
        :order_id => generate_order_id
    }))
    assert_success auth

    assert void = @gateway.void(auth.authorization, reason: 'Test')
    assert_equal format_amount(@amount), auth.params["amount"]
    assert_success void
  end

  def test_failed_void
    response = @gateway.void('', reason: 'Test')
    assert_failure response
    assert_equal "errors.transaction.not_found", response.params["name"]
  end

  ## 8. Verify
  #

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options.merge({
        :order_id => generate_order_id
    }))
    assert_success response
  end

  def test_failed_verify
    response = @gateway.verify(@declined_card, @options.merge({
        :order_id => generate_order_id
    }))
    assert_failure response
    assert_equal "errors.payment.declined", response.params["name"]
  end


  ## 9. Store Card
  #

  # Without Encryption
    # Without customer_ref and customer_id
    def test_successful_store(encryption=false)
      store_successful(encryption, nil)
    end

    def test_failed_store(encryption=false)
      store_failure(encryption, nil)
    end 

    # With Existing Customer
      # With customer_ref
      def test_successful_store_existing_customer_customer_ref(encryption=false)
        store_successful(encryption, true)
      end

      def test_failed_store_existing_customer_customer_ref(encryption=false)
        store_failure(encryption, true)
      end 


    # With Non Existing Customer
      # With customer_ref
      def test_successful_store_non_existing_customer_customer_ref(encryption=false)
        store_successful(encryption, false)
      end

      def test_failed_store_non_existing_customer_customer_ref(encryption=false)
        store_failure(encryption, false)
      end

  ## 10. Unstore Card
  #

  def test_successful_unstore
    store = @gateway.store(@credit_card, @store_options)
    assert_success store

    unstore = @gateway.unstore(store.params["id"])
    assert_success unstore
  end

  def test_failed_unstore
    response = @gateway.unstore('')
    assert_failure response
  end

  ## 11. tore on Purchase
  #

  def test_successful_store_card_on_purchase
    purchase = @gateway.purchase(@amount, @credit_card, @options.merge({
        :order_id => generate_order_id,
        :store_card => true
    }))
    assert_success purchase
    assert (not purchase.params["stored_card"].nil?)
  end

  def test_successful_non_store_card_on_purchase
    purchase = @gateway.purchase(@amount, @credit_card, @options.merge({
        :order_id => generate_order_id,
        :store_card => false
    }))
    assert_success purchase
    assert purchase.params["stored_card"].nil?
  end

end
