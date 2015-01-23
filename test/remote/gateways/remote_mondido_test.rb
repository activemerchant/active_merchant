require 'test_helper'

class RemoteMondidoTest < Test::Unit::TestCase

  def setup
    start_params = fixtures(:mondido)

    # Gateway with Public Key Crypto
    start_params.delete :certificate_for_pinning
    start_params.delete :certificate_hash_for_pinning
    start_params.delete :public_key_for_pinning
    @gateway_encrypted = MondidoGateway.new(start_params)

    # Gateway without Public Key Crypto
    start_params.delete :public_key
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

  def api_request(method, uri, parameters = nil, options = {})
    raw_response = nil
    uri = URI.parse(@gateway.live_url + uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = eval "Net::HTTP::#{method.capitalize}.new(uri.request_uri)"

    # Post Data
    request.set_form_data(parameters) if parameters

    # Add Headers
    auth = "#{fixtures(:mondido)[:merchant_id]}:#{fixtures(:mondido)[:api_token]}"
    headers = {
          "Authorization" => "Basic " + Base64.encode64(auth).strip,
          "User-Agent" => "Mondido ActiveMerchantBindings/#{ActiveMerchant::VERSION}",
          #"X-Mondido-Client-User-Agent" => user_agent, # defined in Gateway.rb
          #"X-Mondido-Client-IP" => options[:ip] if options[:ip]
    }
    headers.keys.each do |header|
      request.add_field(header, headers[header])
    end

    # Do request
    raw_response = http.request(request)

    JSON.parse(raw_response.body)
  end

  def generate_random_number
    rnumber = (@base_order_id + @counter).to_s + Time.now.strftime("%s%L")
    @counter += 1
    return rnumber
  end

  def generate_stored_card
    # Get stored card
    @stored_card ||= nil
    if @stored_card.nil?
      begin
        cards = api_request(:get, "stored_cards")
        cards.each do |card|
          if card["status"] == "active"
            @stored_card = card["token"]
            break
          end
        end

        unless @stored_card
          card = @gateway.store(@credit_card, @store_options)
          @store_card = card.params["token"]
        end
      rescue
        raise "[Setup] Unable to get or create Stored Card Token"
      end
    end

    @stored_card
  end

  def generate_customer_ref_or_id(existing_customer)
      if existing_customer
        # Get customer id
        @customer_id ||= nil
        if @customer_id.nil?
          begin
            customers = api_request(:get, "customers")
            @customer_id = customers[0]["id"] if not customers.empty?

            unless @customer_id
              customer = api_request(:post, "customers")
              @customer_id = customer["id"]
            end
          rescue
            raise "[Setup] Unable to get or create Customer ID"
          end
        end

        return @customer_id
      end

      generate_random_number
  end

  def generate_order_id
    generate_random_number
  end

  def generate_recurring
    # Get plan id
    @plan_id = nil
    if @plan_id.nil?
      begin
        plans = api_request(:get, "plans")
        @plan_id = plans[0]["id"] if not plans.empty?

        unless @plan_id
          plan = api_request(:post, "plans", {
            interval_unit: 'days',
            interval: 30,
            prices: {"eur" => "10","sek" => "100"}.to_json,
            name: "Active Merchant Test"
          })
          @plan_id = plan["id"]
        end
      rescue
        raise "[Setup] Unable to get or create Plan ID"
      end
    end

    @plan_id
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

  def store_response(encryption, existing_customer, identifier, success)
    gateway = encryption ? @gateway_encrypted : @gateway   
    card = success ? @credit_card : @declined_card

    if existing_customer and identifier
      @store_options[:"customer_#{identifier}"] = generate_customer_ref_or_id(existing_customer)
    end

    return gateway.store(card, @store_options)
  end

  def store_successful(encryption, existing_customer, identifier)
    response = store_response(encryption, existing_customer, identifier, true)
    assert_success response
    assert_equal "SEK", response.params["currency"]
    assert_equal "active", response.params["status"]
  end

  def store_failure(encryption, existing_customer, identifier)
    response = store_response(encryption, existing_customer, identifier, false)
    assert_failure response
    assert_equal "errors.payment.declined", response.params["name"]
  end

  def purchase_response(new_options, encryption, authorize, stored_card, success)
    gateway = encryption ? @gateway_encrypted : @gateway
    card = stored_card ? generate_stored_card : @credit_card
    declined_card = stored_card ? @declined_stored_card : @declined_card

    return (authorize ?
      gateway.authorize(@amount, (success ? card : declined_card), new_options)
        :
      gateway.purchase(@amount, (success ? card : declined_card), new_options)
    )
  end

  def purchase_successful(new_options, encryption, authorize, stored_card)
    response = purchase_response(new_options, encryption, authorize, stored_card, true)

    assert_success response
    assert_equal new_options[:order_id], response.params["payment_ref"]
    assert_equal ( authorize ? "authorized" : "approved" ), response.params["status"]
    assert_equal ( stored_card ? "stored_card" : "credit_card" ), response.params["transaction_type"]
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

  def test_valid_pinned_certificate
    # raise "Missing 'certificate_for_pinning' in Fixtures"
    assert fixtures(:mondido)[:certificate_for_pinning]

    start_params = fixtures(:mondido)
    start_params[:public_key] = nil
    start_params[:certificate_hash_for_pinning] = nil
    start_params[:public_key_for_pinning] = nil
    gateway = MondidoGateway.new(start_params)

    response = gateway.purchase(@amount, @credit_card, @options.merge({
        :order_id => generate_order_id
    }))
    assert_success response
  end

  def test_invalid_pinned_certificate
    invalid_certificate = "-----BEGIN CERTIFICATE-----
MIIGxTCCBa2gAwIBAgIIAl5EtcNJFrcwDQYJKoZIhvcNAQEFBQAwSTELMAkGA1UE
BhMCVVMxEzARBgNVBAoTCkdvb2dsZSBJbmMxJTAjBgNVBAMTHEdvb2dsZSBJbnRl
cm5ldCBBdXRob3JpdHkgRzIwHhcNMTQxMjEwMTEzMzM3WhcNMTUwMzEwMDAwMDAw
WjBmMQswCQYDVQQGEwJVUzETMBEGA1UECAwKQ2FsaWZvcm5pYTEWMBQGA1UEBwwN
TW91bnRhaW4gVmlldzETMBEGA1UECgwKR29vZ2xlIEluYzEVMBMGA1UEAwwMKi5n
b29nbGUuY29tMFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEmng6ZoVeVmmAplSC
9TcTQkkosO5zaPDTXLuuzQU3Bl5JUSF/11w6dlXdJJHXIQ3cIirUuyd288ORbu93
FrTTTaOCBF0wggRZMB0GA1UdJQQWMBQGCCsGAQUFBwMBBggrBgEFBQcDAjCCAyYG
A1UdEQSCAx0wggMZggwqLmdvb2dsZS5jb22CDSouYW5kcm9pZC5jb22CFiouYXBw
ZW5naW5lLmdvb2dsZS5jb22CEiouY2xvdWQuZ29vZ2xlLmNvbYIWKi5nb29nbGUt
YW5hbHl0aWNzLmNvbYILKi5nb29nbGUuY2GCCyouZ29vZ2xlLmNsgg4qLmdvb2ds
ZS5jby5pboIOKi5nb29nbGUuY28uanCCDiouZ29vZ2xlLmNvLnVrgg8qLmdvb2ds
ZS5jb20uYXKCDyouZ29vZ2xlLmNvbS5hdYIPKi5nb29nbGUuY29tLmJygg8qLmdv
b2dsZS5jb20uY2+CDyouZ29vZ2xlLmNvbS5teIIPKi5nb29nbGUuY29tLnRygg8q
Lmdvb2dsZS5jb20udm6CCyouZ29vZ2xlLmRlggsqLmdvb2dsZS5lc4ILKi5nb29n
bGUuZnKCCyouZ29vZ2xlLmh1ggsqLmdvb2dsZS5pdIILKi5nb29nbGUubmyCCyou
Z29vZ2xlLnBsggsqLmdvb2dsZS5wdIISKi5nb29nbGVhZGFwaXMuY29tgg8qLmdv
b2dsZWFwaXMuY26CFCouZ29vZ2xlY29tbWVyY2UuY29tghEqLmdvb2dsZXZpZGVv
LmNvbYIMKi5nc3RhdGljLmNugg0qLmdzdGF0aWMuY29tggoqLmd2dDEuY29tggoq
Lmd2dDIuY29tghQqLm1ldHJpYy5nc3RhdGljLmNvbYIMKi51cmNoaW4uY29tghAq
LnVybC5nb29nbGUuY29tghYqLnlvdXR1YmUtbm9jb29raWUuY29tgg0qLnlvdXR1
YmUuY29tghYqLnlvdXR1YmVlZHVjYXRpb24uY29tggsqLnl0aW1nLmNvbYILYW5k
cm9pZC5jb22CBGcuY2+CBmdvby5nbIIUZ29vZ2xlLWFuYWx5dGljcy5jb22CCmdv
b2dsZS5jb22CEmdvb2dsZWNvbW1lcmNlLmNvbYIKdXJjaGluLmNvbYIIeW91dHUu
YmWCC3lvdXR1YmUuY29tghR5b3V0dWJlZWR1Y2F0aW9uLmNvbTALBgNVHQ8EBAMC
B4AwaAYIKwYBBQUHAQEEXDBaMCsGCCsGAQUFBzAChh9odHRwOi8vcGtpLmdvb2ds
ZS5jb20vR0lBRzIuY3J0MCsGCCsGAQUFBzABhh9odHRwOi8vY2xpZW50czEuZ29v
Z2xlLmNvbS9vY3NwMB0GA1UdDgQWBBTn6rT+UWACLuZnUas2zTQJkdrq5jAMBgNV
HRMBAf8EAjAAMB8GA1UdIwQYMBaAFErdBhYbvPZotXb1gba7Yhq6WoEvMBcGA1Ud
IAQQMA4wDAYKKwYBBAHWeQIFATAwBgNVHR8EKTAnMCWgI6Ahhh9odHRwOi8vcGtp
Lmdvb2dsZS5jb20vR0lBRzIuY3JsMA0GCSqGSIb3DQEBBQUAA4IBAQBb4wU7IjXL
msvaYqFlYYDKiYZhBUGHxxLkFWR72vFugYkJ7BbMCaKZJdyln5xL4pCdNHiNGfub
/3ct2t3sKeruc03EydznLQ78qrHuwNJdqUZfDLJ6ILAQUmpnYEXrnmB7C5chCWR0
OKWRLguwZQQQQlRyjZFtdoISHNveel/UkS/Jwijvpbw/wGg9W4L4En6RjDeD259X
zYvNzIwiEq50/5ZQCYE9EH0mWguAji9tuh5NJKPEeaaCQ3lp/UEAkq5uYls7tuSs
MTI9LMZRiYFJab/LYbq2uaz4B/lSuE9vku+ikNYA+J2Qv6eqU3U+jmUOSCfYJ2Qt
zSl8TUu4bL8a
-----END CERTIFICATE-----
"
    start_params = fixtures(:mondido)
    start_params[:public_key] = nil
    start_params[:certificate_for_pinning] = invalid_certificate
    start_params[:certificate_hash_for_pinning] = nil
    start_params[:public_key_for_pinning] = nil
    gateway = MondidoGateway.new(start_params)

    response = gateway.purchase(@amount, @credit_card, @options.merge({
        :order_id => generate_order_id
    }))
    assert_failure response
    assert_equal "Security Problem: pinned certificate doesn't match the server certificate.", response.message
  end

  def test_valid_pinned_certificate_hash
    # "Missing 'certificate_hash_for_pinning' in Fixtures"
    assert fixtures(:mondido)[:certificate_hash_for_pinning]

    start_params = fixtures(:mondido)
    start_params[:public_key] = nil
    start_params[:certificate_for_pinning] = nil
    start_params[:public_key_for_pinning] = nil
    gateway = MondidoGateway.new(start_params)

    response = gateway.purchase(@amount, @credit_card, @options.merge({
        :order_id => generate_order_id
    }))
    assert_success response
  end

  def test_invalid_pinned_certificate_hash
    start_params = fixtures(:mondido)
    start_params[:public_key] = nil
    start_params[:certificate_for_pinning] = nil
    start_params[:public_key_for_pinning] = nil
    start_params[:certificate_hash_for_pinning] = "invalid hash"
    gateway = MondidoGateway.new(start_params)

    response = gateway.purchase(@amount, @credit_card, @options.merge({
        :order_id => generate_order_id
    }))
    assert_failure response
    assert_equal "Security Problem: pinned certificate doesn't match the server certificate.", response.message
  end

  def test_valid_pinned_public_key
    # "Missing 'public_key_for_pinning' in Fixtures"
    assert fixtures(:mondido)[:public_key_for_pinning]

    start_params = fixtures(:mondido)
    start_params[:public_key] = nil
    start_params[:certificate_for_pinning] = nil
    start_params[:certificate_hash_for_pinning] = nil
    gateway = MondidoGateway.new(start_params)

    response = gateway.purchase(@amount, @credit_card, @options.merge({
        :order_id => generate_order_id
    }))
    assert_success response
  end

  def test_invalid_pinned_public_key
    start_params = fixtures(:mondido)
    start_params[:public_key] = nil
    start_params[:certificate_for_pinning] = nil
    start_params[:certificate_hash_for_pinning] = nil
    start_params[:public_key_for_pinning] = "-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA1GyXNJG2Tzwof4z4S0Dz
hhY8Ht3gdoO8N4YKdPH+hkRDgtLlOyTB9YZ+3QJh77aed7xBlHXdZ9dlTeCmGUOM
rHARGh845Iu1GfdgM8+L3TFeOsNgy2xeHCdIjSbYbHcj13tdOBsKQyn6BRVR8+Ym
a2WKXVN3lOgWlr/NEeBwiwQZW4F4WUEqQSEpNFfGAReW0EMUalPWoXMgyxWDL7/A
kax11h+O8HKK/D0flGF/ZRfY5ybyYbQWaMWSfo0pSeay1m7Irbae4YW9gI1YKrmB
JiLNKynvxE4IbTpKzug77yi8L1tMJsn65QMEYlpus4GvSn3PHAz5unA/9YX7gjyO
ZwIDAQAB
-----END PUBLIC KEY-----"
    gateway = MondidoGateway.new(start_params)

    response = gateway.purchase(@amount, @credit_card, @options.merge({
        :order_id => generate_order_id
    }))
    assert_failure response
    assert_equal "Security Problem: pinned public key doesn't match the server public key.", response.message
  end

  ## 3. Purchase
  #

  # With Encryption
  # With Credit Card
  # With Recurring
  # With Web Hooks
  # With Meta Data

  def test_successful_purchase_encryption_credit_card_recurring_webhook_metadata
    test_successful_purchase_credit_card_recurring_webhook_metadata(true)
  end

  def test_failed_purchase_encryption_credit_card_recurring_webhook_metadata
    test_failed_purchase_credit_card_recurring_webhook_metadata(true)
  end

  # Without Meta Data

  def test_successful_purchase_encryption_credit_card_recurring_webhook
    test_successful_purchase_credit_card_recurring_webhook(true)
  end

  def test_failed_purchase_encryption_credit_card_recurring_webhook
    test_failed_purchase_credit_card_recurring_webhook(true)
  end

  # Without Web Hooks

  # With Meta Data

  def test_successful_purchase_encryption_credit_card_recurring_metadata
    test_successful_purchase_credit_card_recurring_metadata(true)
  end

  def test_failed_purchase_encryption_credit_card_recurring_metadata
    test_failed_purchase_credit_card_recurring_metadata(true)
  end

  # Without Meta Data

  def test_successful_purchase_encryption_credit_card_recurring
    test_successful_purchase_credit_card_recurring(true)
  end

  def test_failed_purchase_encryption_credit_card_recurring
    test_failed_purchase_credit_card_recurring(true)
  end

  # Without Recurring

  # With Meta Data

  def test_successful_purchase_encryption_credit_card_webhook_metadata
    test_successful_purchase_credit_card_webhook_metadata(true)
  end

  def test_failed_purchase_encryption_credit_card_webhook_metadata
    test_failed_purchase_credit_card_webhook_metadata(true)
  end

  # Without Meta Data

  def test_successful_purchase_encryption_credit_card_webhook
    test_successful_purchase_credit_card_webhook(true)
  end

  def test_failed_purchase_encryption_credit_card_webhook
    test_failed_purchase_credit_card_webhook(true)
  end

  # Without Web Hooks

  # With Meta Data

  def test_successful_purchase_encryption_credit_card_metadata
    test_successful_purchase_credit_card_metadata(true)
  end

  def test_failed_purchase_encryption_credit_card_metadata
    test_failed_purchase_credit_card_metadata(true)
  end

  # Without Meta Data

  def test_successful_purchase_encryption_credit_card
    test_successful_purchase_credit_card(true)
  end

  def test_failed_purchase_encryption_credit_card
    test_failed_purchase_credit_card(true)
  end

  # With Stored Card
  # With Recurring
  # With Web Hooks
  # With Meta Data

  def test_successful_purchase_encryption_stored_card_recurring_webhook_metadata
    test_successful_purchase_stored_card_recurring_webhook_metadata(true)
  end

  def test_failed_purchase_encryption_stored_card_recurring_webhook_metadata
    test_failed_purchase_stored_card_recurring_webhook_metadata(true)
  end

  # Without Meta Data

  def test_successful_purchase_encryption_stored_card_recurring_webhook
    test_successful_purchase_stored_card_recurring_webhook(true)
  end

  def test_failed_purchase_encryption_stored_card_recurring_webhook
    test_failed_purchase_stored_card_recurring_webhook(true)
  end

  # Without Web Hooks

  # With Meta Data

  def test_successful_purchase_encryption_stored_card_recurring_metadata
    test_successful_purchase_stored_card_recurring_metadata(true)
  end

  def test_failed_purchase_encryption_stored_card_recurring_metadata
    test_failed_purchase_stored_card_recurring_metadata(true)
  end

  # Without Meta Data

  def test_successful_purchase_encryption_stored_card_recurring
    test_successful_purchase_stored_card_recurring(true)
  end

  def test_failed_purchase_encryption_stored_card_recurring
    test_failed_purchase_stored_card_recurring(true)
  end

  # Without Recurring

  # With Meta Data

  def test_successful_purchase_encryption_stored_card_webhook_metadata
    test_successful_purchase_stored_card_webhook_metadata(true)
  end

  def test_failed_purchase_encryption_stored_card_webhook_metadata
    test_failed_purchase_stored_card_webhook_metadata(true)
  end

  # Without Meta Data

  def test_successful_purchase_encryption_stored_card_webhook
    test_successful_purchase_stored_card_webhook(true)
  end

  def test_failed_purchase_encryption_stored_card_webhook
    test_failed_purchase_stored_card_webhook(true)
  end

  # Without Web Hooks

  # With Meta Data

  def test_successful_purchase_encryption_stored_card_metadata
    test_successful_purchase_stored_card_metadata(true)
  end

  def test_failed_purchase_encryption_stored_card_metadata
    test_failed_purchase_stored_card_metadata(true)
  end

  # Without Meta Data

  def test_successful_purchase_encryption_stored_card
    test_successful_purchase_stored_card(true)
  end

  def test_failed_purchase_encryption_stored_card
    test_failed_purchase_stored_card(true)
  end

  # Without Encryption

  def test_successful_purchase_credit_card_recurring_webhook_metadata(encryption=false, authorize=false, stored=false)
    new_options = @options.merge({
      :order_id => generate_order_id,
      :plan_id => generate_recurring,
      :webhook => generate_webhook,
      :metadata => generate_metadata
    })
    purchase_successful(new_options, encryption, authorize, stored)
  end

  def test_failed_purchase_credit_card_recurring_webhook_metadata(encryption=false, authorize=false, stored=false)
    new_options = @options.merge({
      :order_id => generate_order_id,
      :plan_id => generate_recurring,
      :webhook => generate_webhook,
      :metadata => generate_metadata
    })
    purchase_failure(new_options, encryption, authorize, stored)
  end

  # Without Meta Data

  def test_successful_purchase_credit_card_recurring_webhook(encryption=false, authorize=false, stored=false)
    new_options = @options.merge({
      :order_id => generate_order_id,
      :plan_id => generate_recurring,
      :webhook => generate_webhook
    })
    purchase_successful(new_options, encryption, authorize, stored)
  end

  def test_failed_purchase_credit_card_recurring_webhook(encryption=false, authorize=false, stored=false)
    new_options = @options.merge({
      :order_id => generate_order_id,
      :plan_id => generate_recurring,
      :webhook => generate_webhook
    })
    purchase_failure(new_options, encryption, authorize, stored)
  end

  # Without Web Hooks

  # With Meta Data

  def test_successful_purchase_credit_card_recurring_metadata(encryption=false, authorize=false, stored=false)
    new_options = @options.merge({
      :order_id => generate_order_id,
      :plan_id => generate_recurring,
      :metadata => generate_metadata
    })
    purchase_successful(new_options, encryption, authorize, stored)
  end

  def test_failed_purchase_credit_card_recurring_metadata(encryption=false, authorize=false, stored=false)
    new_options = @options.merge({
      :order_id => generate_order_id,
      :plan_id => generate_recurring,
      :metadata => generate_metadata
    })
    purchase_failure(new_options, encryption, authorize, stored)
  end

  # Without Meta Data

  def test_successful_purchase_credit_card_recurring(encryption=false, authorize=false, stored=false)
    new_options = @options.merge({
      :order_id => generate_order_id,
      :plan_id => generate_recurring
    })
    purchase_successful(new_options, encryption, authorize, stored)
  end

  def test_failed_purchase_credit_card_recurring(encryption=false, authorize=false, stored=false)
    new_options = @options.merge({
      :order_id => generate_order_id,
      :plan_id => generate_recurring
    })
    purchase_failure(new_options, encryption, authorize, stored)
  end

  # Without Recurring

  # With Web Hook

  # With Meta Data

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
  # With Recurring
  # With Web Hooks
  # With Meta Data

  def test_successful_purchase_stored_card_recurring_webhook_metadata(encryption=false, authorize=false, stored=true)
    test_successful_purchase_credit_card_recurring_webhook_metadata(encryption, authorize, stored)
  end

  def test_failed_purchase_stored_card_recurring_webhook_metadata(encryption=false, authorize=false, stored=true)
    test_failed_purchase_credit_card_recurring_webhook_metadata(encryption, authorize, stored)
  end

  # Without Meta Data

  def test_successful_purchase_stored_card_recurring_webhook(encryption=false, authorize=false, stored=true)
    test_successful_purchase_credit_card_recurring_webhook(encryption, authorize, stored)
  end

  def test_failed_purchase_stored_card_recurring_webhook(encryption=false, authorize=false, stored=true)
    test_failed_purchase_credit_card_recurring_webhook(encryption, authorize, stored)
  end

  # Without Web Hooks

  # With Meta Data

  def test_successful_purchase_stored_card_recurring_metadata(encryption=false, authorize=false, stored=true)
    test_successful_purchase_credit_card_recurring_metadata(encryption, authorize, stored)
  end

  def test_failed_purchase_stored_card_recurring_metadata(encryption=false, authorize=false, stored=true)
    test_failed_purchase_credit_card_recurring_metadata(encryption, authorize, stored)
  end

  # Without Meta Data

  def test_successful_purchase_stored_card_recurring(encryption=false, authorize=false, stored=true)
    test_successful_purchase_credit_card_recurring(encryption, authorize, stored)
  end

  def test_failed_purchase_stored_card_recurring(encryption=false, authorize=false, stored=true)
    test_failed_purchase_credit_card_recurring(encryption, authorize, stored)
  end

  # Without Recurring

  # With Meta Data

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

  def test_successful_authorize_encryption_credit_card_recurring_webhook_metadata
    test_successful_purchase_credit_card_recurring_webhook_metadata(true, true)
  end

  def test_failed_authorize_encryption_credit_card_recurring_webhook_metadata
    test_failed_purchase_credit_card_recurring_webhook_metadata(true, true)
  end

  # Without Meta Data

  def test_successful_authorize_encryption_credit_card_recurring_webhook
    test_successful_purchase_credit_card_recurring_webhook(true, true)
  end

  def test_failed_authorize_encryption_credit_card_recurring_webhook
    test_failed_purchase_credit_card_recurring_webhook(true, true)
  end

  # Without Web Hooks

  # With Meta Data

  def test_successful_authorize_encryption_credit_card_recurring_metadata
    test_successful_purchase_credit_card_recurring_metadata(true, true)
  end

  def test_failed_authorize_encryption_credit_card_recurring_metadata
    test_failed_purchase_credit_card_recurring_metadata(true, true)
  end

  # Without Meta Data

  def test_successful_authorize_encryption_credit_card_recurring
    test_successful_purchase_credit_card_recurring(true, true)
  end

  def test_failed_authorize_encryption_credit_card_recurring
    test_failed_purchase_credit_card_recurring(true, true)
  end

  # Without Recurring

  # With Meta Data

  def test_successful_authorize_encryption_credit_card_webhook_metadata
    test_successful_purchase_credit_card_webhook_metadata(true, true)
  end

  def test_failed_authorize_encryption_credit_card_webhook_metadata
    test_failed_purchase_credit_card_webhook_metadata(true, true)
  end

  # Without Meta Data

  def test_successful_authorize_encryption_credit_card_webhook
    test_successful_purchase_credit_card_webhook(true, true)
  end

  def test_failed_authorize_encryption_credit_card_webhook
    test_failed_purchase_credit_card_webhook(true, true)
  end

  # Without Web Hooks

  # With Meta Data

  def test_successful_authorize_encryption_credit_card_metadata
    test_successful_purchase_credit_card_metadata(true, true)
  end

  def test_failed_authorize_encryption_credit_card_metadata
    test_failed_purchase_credit_card_metadata(true, true)
  end

  # Without Meta Data

  def test_successful_authorize_encryption_credit_card
    test_successful_purchase_credit_card(true, true)
  end

  def test_failed_authorize_encryption_credit_card
    test_failed_purchase_credit_card(true, true)
  end

  # With Stored Card
  # With Recurring
  # With Web Hooks
  # With Meta Data

  def test_successful_authorize_encryption_stored_card_recurring_webhook_metadata
    test_successful_purchase_stored_card_recurring_webhook_metadata(true, true)
  end

  def test_failed_authorize_encryption_stored_card_recurring_webhook_metadata
    test_failed_purchase_stored_card_recurring_webhook_metadata(true, true)
  end

  # Without Meta Data

  def test_successful_authorize_encryption_stored_card_recurring_webhook
    test_successful_purchase_stored_card_recurring_webhook(true, true)
  end

  def test_failed_authorize_encryption_stored_card_recurring_webhook
    test_failed_purchase_stored_card_recurring_webhook(true, true)
  end

  # Without Web Hooks

  # With Meta Data

  def test_successful_authorize_encryption_stored_card_recurring_metadata
    test_successful_purchase_stored_card_recurring_metadata(true, true)
  end

  def test_failed_authorize_encryption_stored_card_recurring_metadata
    test_failed_purchase_stored_card_recurring_metadata(true, true)
  end

  # Without Meta Data

  def test_successful_authorize_encryption_stored_card_recurring
    test_successful_purchase_stored_card_recurring(true, true)
  end

  def test_failed_authorize_encryption_stored_card_recurring
    test_failed_purchase_stored_card_recurring(true, true)
  end

  # Without Recurring

  # With Meta Data

  def test_successful_authorize_encryption_stored_card_webhook_metadata
    test_successful_purchase_stored_card_webhook_metadata(true, true)
  end

  def test_failed_authorize_encryption_stored_card_webhook_metadata
    test_failed_purchase_stored_card_webhook_metadata(true, true)
  end

  # Without Meta Data

  def test_successful_authorize_encryption_stored_card_webhook
    test_successful_purchase_stored_card_webhook(true, true)
  end

  def test_failed_authorize_encryption_stored_card_webhook
    test_failed_purchase_stored_card_webhook(true, true)
  end

  # Without Web Hooks

  # With Meta Data

  def test_successful_authorize_encryption_stored_card_metadata
    test_successful_purchase_stored_card_metadata(true, true)
  end

  def test_failed_authorize_encryption_stored_card_metadata
    test_failed_purchase_stored_card_metadata(true, true)
  end

  # Without Meta Data

  def test_successful_authorize_encryption_stored_card
    test_successful_purchase_stored_card(true, true)
  end

  def test_failed_authorize_encryption_stored_card
    test_failed_purchase_stored_card(true, true)
  end

  # Without Encryption

  def test_successful_authorize_credit_card_recurring_webhook_metadata
    test_successful_purchase_credit_card_recurring_webhook_metadata(false, true, false)
  end

  def test_failed_authorize_credit_card_recurring_webhook_metadata
    test_failed_purchase_credit_card_recurring_webhook_metadata(false, true, false)
  end

  # Without Meta Data

  def test_successful_authorize_credit_card_recurring_webhook
    test_successful_purchase_credit_card_recurring_webhook(false, true, false)
  end

  def test_failed_authorize_credit_card_recurring_webhook
    test_failed_purchase_credit_card_recurring_webhook(false, true, false)
  end

  # Without Web Hooks

  # With Meta Data

  def test_successful_authorize_credit_card_recurring_metadata
    test_successful_purchase_credit_card_recurring_metadata(false, true, false)
  end

  def test_failed_authorize_credit_card_recurring_metadata
    test_failed_purchase_credit_card_recurring_metadata(false, true, false)
  end

  # Without Meta Data

  def test_successful_authorize_credit_card_recurring
    test_successful_purchase_credit_card_recurring(false, true, false)
  end

  def test_failed_authorize_credit_card_recurring
    test_failed_purchase_credit_card_recurring(false, true, false)
  end

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
  # With Recurring
  # With Web Hooks
  # With Meta Data

  def test_successful_authorize_stored_card_recurring_webhook_metadata
    test_successful_purchase_credit_card_recurring_webhook_metadata(false, true, true)
  end

  def test_failed_authorize_stored_card_recurring_webhook_metadata
    test_failed_purchase_credit_card_recurring_webhook_metadata(false, false, true)
  end

  # Without Meta Data

  def test_successful_authorize_stored_card_recurring_webhook
    test_successful_purchase_credit_card_recurring_webhook(false, false, true)
  end

  def test_failed_authorize_stored_card_recurring_webhook
    test_failed_purchase_credit_card_recurring_webhook(false, true, true)
  end

  # Without Web Hooks

  # With Meta Data

  def test_successful_authorize_stored_card_recurring_metadata
    test_successful_purchase_credit_card_recurring_metadata(false, true, true)
  end

  def test_failed_authorize_stored_card_recurring_metadata
    test_failed_purchase_credit_card_recurring_metadata(false, true, true)
  end

  # Without Meta Data

  def test_successful_authorize_stored_card_recurring
    test_successful_purchase_credit_card_recurring(false, true, true)
  end

  def test_failed_authorize_stored_card_recurring
    test_failed_purchase_credit_card_recurring(false, true, true)
  end

  # Without Recurring

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

  # With Encryption
    # Without customer_ref and customer_id
    def test_encryption_successful_store
      test_successful_store(true)
    end

    def test_encryption_failed_store
      test_failed_store(true)
    end 

    # With Existing Customer
      # With customer_ref
      def test_successful_store_encryption_existing_customer_customer_ref
        test_successful_store_existing_customer_customer_ref(true)
      end

      def test_failed_store_encryption_existing_customer_customer_ref
        test_failed_store_existing_customer_customer_ref(true)
      end

      # With customer_id
      def test_successful_store_encryption_existing_customer_customer_id
        test_successful_store_existing_customer_customer_id(true)
      end

      def test_failed_store_encryption_existing_customer_customer_id
        test_failed_store_existing_customer_customer_id(true)
      end
    # With Non Existing Customer
      # With customer_ref
      def test_successful_store_encryption_non_existing_customer_customer_ref
        test_successful_store_non_existing_customer_customer_ref(true)
      end

      def test_failed_store_encryption_non_existing_customer_customer_ref
        test_failed_store_non_existing_customer_customer_ref(true)
      end

      # With customer_id
      def test_failed_store_encryption_non_existing_customer_customer_id
        test_failed_store_non_existing_customer_customer_id(true)
      end

  # Without Encryption
    # Without customer_ref and customer_id
    def test_successful_store(encryption=false)
      store_successful(encryption, nil, nil)
    end

    def test_failed_store(encryption=false)
      store_failure(encryption, nil, nil)
    end 

    # With Existing Customer
      # With customer_ref
      def test_successful_store_existing_customer_customer_ref(encryption=false)
        store_successful(encryption, true, 'ref')
      end

      def test_failed_store_existing_customer_customer_ref(encryption=false)
        store_failure(encryption, true, 'ref')
      end 
      # With customer_id
      def test_successful_store_existing_customer_customer_id(encryption=false)
        store_successful(encryption, true, 'id')
      end

      def test_failed_store_existing_customer_customer_id(encryption=false)
        store_failure(encryption, true, 'id')
      end

    # With Non Existing Customer
      # With customer_ref
      def test_successful_store_non_existing_customer_customer_ref(encryption=false)
        store_successful(encryption, false, 'ref')
      end

      def test_failed_store_non_existing_customer_customer_ref(encryption=false)
        store_failure(encryption, false, 'ref')
      end

      # With customer_id
      def test_failed_store_non_existing_customer_customer_id(encryption=false)
        store_failure(encryption, false, 'id')
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

  ## 11. Extendability, Locale, Store on Purchase
  #

  def test_successful_extendability
    purchase = @gateway.purchase(@amount, generate_stored_card, @options.merge({
        :order_id => generate_order_id,
        :extend => "stored_card",
        :locale => "en",
        :start_id => 0,
        :limit => 9999999
    }))
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization, {
      :reason => "Test"
    })

    assert_success refund
    assert_equal format_amount(@amount), purchase.params["amount"]
    assert_equal purchase.params["merchant_id"], purchase.params["stored_card"]["merchant_id"]
  end

  def test_successful_locale_en
    response = @gateway.unstore('1', {
      :locale => "en"
    })
    assert_failure response
    assert_equal "Unauthorized", response.message
  end

  def test_successful_locale_se
    response = @gateway.unstore('1', {
      :locale => "se"
    })
    assert_failure response
    assert_equal "Ej beh\xC3\xB6rig", response.message
  end

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
