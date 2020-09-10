require 'test_helper.rb'

class RemoteOrbitalGatewayTest < Test::Unit::TestCase
  def setup
    Base.mode = :test
    @gateway = ActiveMerchant::Billing::OrbitalGateway.new(fixtures(:orbital_gateway))

    @amount = 100
    @credit_card = credit_card('4112344112344113')
    @declined_card = credit_card('4000300011112220')

    @options = {
      order_id: generate_unique_id,
      address: address,
      merchant_id: 'merchant1234'
    }

    @cards = {
      visa: '4788250000028291',
      mc: '5454545454545454',
      amex: '371449635398431',
      ds: '6011000995500000',
      diners: '36438999960016',
      jcb: '3566002020140006'
    }

    @level_2_options = {
      tax_indicator: '1',
      tax: '75',
      advice_addendum_1: 'taa1 - test',
      advice_addendum_2: 'taa2 - test',
      advice_addendum_3: 'taa3 - test',
      advice_addendum_4: 'taa4 - test',
      purchase_order: '123abc',
      name: address[:name],
      address1: address[:address1],
      address2: address[:address2],
      city: address[:city],
      state: address[:state],
      zip: address[:zip],
    }

    @test_suite = [
      {card: :visa, AVSzip: 11111, CVD: 111,  amount: 3000},
      {card: :visa, AVSzip: 33333, CVD: nil,  amount: 3801},
      {card: :mc,   AVSzip: 44444, CVD: nil,  amount: 4100},
      {card: :mc,   AVSzip: 88888, CVD: 666,  amount: 1102},
      {card: :amex, AVSzip: 55555, CVD: nil,  amount: 105500},
      {card: :amex, AVSzip: 66666, CVD: 2222, amount: 7500},
      {card: :ds,   AVSzip: 77777, CVD: nil,  amount: 1000},
      {card: :ds,   AVSzip: 88888, CVD: 444,  amount: 6303},
      {card: :jcb,  AVSzip: 33333, CVD: nil,  amount: 2900}
    ]
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_successful_purchase_with_soft_descriptor_hash
    options = @options.merge(
      soft_descriptors: {
        merchant_name: 'Merch',
        product_description: 'Description',
        merchant_email: 'email@example'
      }
    )
    assert response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_successful_purchase_with_level_2_data
    response = @gateway.purchase(@amount, @credit_card, @options.merge(level_2_data: @level_2_options))

    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_successful_purchase_with_visa_network_tokenization_credit_card_with_eci
    network_card = network_tokenization_credit_card('4788250000028291',
      payment_cryptogram: 'BwABB4JRdgAAAAAAiFF2AAAAAAA=',
      transaction_id: 'BwABB4JRdgAAAAAAiFF2AAAAAAA=',
      verification_value: '111',
      brand: 'visa',
      eci: '5'
    )
    assert response = @gateway.purchase(3000, network_card, @options)
    assert_success response
    assert_equal 'Approved', response.message
    assert_false response.authorization.blank?
  end

  def test_successful_purchase_with_master_card_network_tokenization_credit_card
    network_card = network_tokenization_credit_card('4788250000028291',
      payment_cryptogram: 'BwABB4JRdgAAAAAAiFF2AAAAAAA=',
      transaction_id: 'BwABB4JRdgAAAAAAiFF2AAAAAAA=',
      verification_value: '111',
      brand: 'master'
    )
    assert response = @gateway.purchase(3000, network_card, @options)
    assert_success response
    assert_equal 'Approved', response.message
    assert_false response.authorization.blank?
  end

  def test_successful_purchase_with_american_express_network_tokenization_credit_card
    network_card = network_tokenization_credit_card('4788250000028291',
      payment_cryptogram: 'BwABB4JRdgAAAAAAiFF2AAAAAAA=',
      transaction_id: 'BwABB4JRdgAAAAAAiFF2AAAAAAA=',
      verification_value: '111',
      brand: 'american_express'
    )
    assert response = @gateway.purchase(3000, network_card, @options)
    assert_success response
    assert_equal 'Approved', response.message
    assert_false response.authorization.blank?
  end

  def test_successful_purchase_with_discover_network_tokenization_credit_card
    network_card = network_tokenization_credit_card('4788250000028291',
      payment_cryptogram: 'BwABB4JRdgAAAAAAiFF2AAAAAAA=',
      transaction_id: 'BwABB4JRdgAAAAAAiFF2AAAAAAA=',
      verification_value: '111',
      brand: 'discover'
    )
    assert response = @gateway.purchase(3000, network_card, @options)
    assert_success response
    assert_equal 'Approved', response.message
    assert_false response.authorization.blank?
  end

  [
    {
      card: {
        number: '4112344112344113',
        verification_value: '411',
        brand: 'visa',
      },
      three_d_secure: {
        eci: '5',
        cavv: 'AAABAIcJIoQDIzAgVAkiAAAAAAA=',
        xid: 'AAABAIcJIoQDIzAgVAkiAAAAAAA=',
      },
      address: {
        address1: '55 Forever Ave',
        address2: '',
        city: 'Concord',
        state: 'NH',
        zip: '03301',
        country: 'US',
      },
    },
    {
      card: {
        number: '5112345112345114',
        verification_value: '823',
        brand: 'master',
      },
      three_d_secure: {
        eci: '6',
        cavv: 'Asju1ljfl86bAAAAAACm9zU6aqY=',
        xid: 'Asju1ljfl86bAAAAAACm9zU6aqY=',
      },
      address: {
        address1: 'Byway Street',
        address2: '',
        city: 'Portsmouth',
        state: 'MA',
        zip: '',
        country: 'US',
      },
    },
    {
      card: {
        number: '371144371144376',
        verification_value: '1234',
        brand: 'american_express',
      },
      three_d_secure: {
        eci: '5',
        cavv: 'AAABBWcSNIdjeUZThmNHAAAAAAA=',
        xid: 'AAABBWcSNIdjeUZThmNHAAAAAAA=',
      },
      address: {
        address1: '4 Northeastern Blvd',
        address2: '',
        city: 'Salem',
        state: 'NH',
        zip: '03105',
        country: 'US',
      },
    }
  ].each do |fixture|
    define_method("test_successful_#{fixture[:card][:brand]}_authorization_with_3ds") do
      cc = credit_card(fixture[:card][:number], {
        verification_value: fixture[:card][:verification_value],
        brand: fixture[:card][:brand]
      })
      options = @options.merge(
        order_id: '2',
        currency: 'USD',
        three_d_secure: fixture[:three_d_secure],
        address: fixture[:address]
      )
      assert response = @gateway.authorize(100, cc, options)

      assert_success response
      assert_equal 'Approved', response.message
      assert_false response.authorization.blank?
    end

    define_method("test_successful_#{fixture[:card][:brand]}_purchase_with_3ds") do
      cc = credit_card(fixture[:card][:number], {
        verification_value: fixture[:card][:verification_value],
        brand: fixture[:card][:brand]
      })
      options = @options.merge(
        order_id: '2',
        currency: 'USD',
        three_d_secure: fixture[:three_d_secure],
        address: fixture[:address]
      )
      assert response = @gateway.purchase(100, cc, options)

      assert_success response
      assert_equal 'Approved', response.message
      assert_false response.authorization.blank?
    end
  end

  def test_successful_purchase_with_mit_stored_credentials
    mit_stored_credentials = {
      mit_msg_type: 'MUSE',
      mit_stored_credential_ind: 'Y',
      mit_submitted_transaction_id: 'abcdefg12345678'
    }

    response = @gateway.purchase(@amount, @credit_card, @options.merge(mit_stored_credentials))

    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_successful_purchase_with_cit_stored_credentials
    cit_options = {
      mit_msg_type: 'CUSE',
      mit_stored_credential_ind: 'Y'
    }

    response = @gateway.purchase(@amount, @credit_card, @options.merge(cit_options))

    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_purchase_using_stored_credential_recurring_cit
    initial_options = stored_credential_options(:cardholder, :recurring, :initial)
    assert purchase = @gateway.purchase(@amount, @credit_card, initial_options)
    assert_success purchase
    assert_equal 'Approved', purchase.message
    assert network_transaction_id = purchase.params['mit_received_transaction_id']

    used_options = stored_credential_options(:recurring, :cardholder, id: network_transaction_id)
    assert purchase = @gateway.purchase(@amount, @credit_card, used_options)
    assert_success purchase
    assert_equal 'Approved', purchase.message
  end

  def test_purchase_using_stored_credential_recurring_mit
    initial_options = stored_credential_options(:merchant, :recurring, :initial)
    assert purchase = @gateway.purchase(@amount, @credit_card, initial_options)
    assert_success purchase
    assert_equal 'Approved', purchase.message
    assert network_transaction_id = purchase.params['mit_received_transaction_id']

    used_options = stored_credential_options(:recurring, :merchant, id: network_transaction_id)
    assert purchase = @gateway.purchase(@amount, @credit_card, used_options)
    assert_success purchase
    assert_equal 'Approved', purchase.message
  end

  def test_successful_purchase_with_overridden_normalized_stored_credentials
    stored_credential = {
      stored_credential: {
        initial_transaction: false,
        initiator: 'merchant',
        reason_type: 'unscheduled',
        network_transaction_id: 'abcdefg12345678'
      },
      mit_msg_type: 'MRSB'
    }

    response = @gateway.purchase(@amount, @credit_card, @options.merge(stored_credential))

    assert_success response
    assert_equal 'Approved', response.message
  end

  # Amounts of x.01 will fail
  def test_unsuccessful_purchase
    assert response = @gateway.purchase(101, @declined_card, @options)
    assert_failure response
    assert_equal 'Invalid CC Number', response.message
  end

  def test_authorize_and_capture
    amount = @amount
    assert auth = @gateway.authorize(amount, @credit_card, @options.merge(order_id: '2'))
    assert_success auth
    assert_equal 'Approved', auth.message
    assert auth.authorization
    assert capture = @gateway.capture(amount, auth.authorization, order_id: '2')
    assert_success capture
  end

  def test_successful_authorize_and_capture_with_level_2_data
    auth = @gateway.authorize(@amount, @credit_card, @options.merge(level_2_data: @level_2_options))
    assert_success auth
    assert_equal 'Approved', auth.message

    capture = @gateway.capture(@amount, auth.authorization, @options.merge(level_2_data: @level_2_options))
    assert_success capture
  end

  def test_authorize_and_void
    assert auth = @gateway.authorize(@amount, @credit_card, @options.merge(order_id: '2'))
    assert_success auth
    assert_equal 'Approved', auth.message
    assert auth.authorization
    assert void = @gateway.void(auth.authorization, order_id: '2')
    assert_success void
  end

  def test_refund
    amount = @amount
    assert response = @gateway.purchase(amount, @credit_card, @options)
    assert_success response
    assert response.authorization
    assert refund = @gateway.refund(amount, response.authorization, @options)
    assert_success refund
  end

  def test_successful_refund_with_level_2_data
    amount = @amount
    assert response = @gateway.purchase(amount, @credit_card, @options.merge(level_2_data: @level_2_options))
    assert_success response
    assert response.authorization
    assert refund = @gateway.refund(amount, response.authorization, @options.merge(level_2_data: @level_2_options))
    assert_success refund
  end

  def test_failed_capture
    assert response = @gateway.capture(@amount, '')
    assert_failure response
    assert_equal 'Bad data error', response.message
  end

  # == Certification Tests

  # ==== Section A
  def test_auth_only_transactions
    for suite in @test_suite do
      amount = suite[:amount]
      card = credit_card(@cards[suite[:card]], verification_value: suite[:CVD])
      @options[:address][:zip] = suite[:AVSzip]
      assert response = @gateway.authorize(amount, card, @options)
      assert_kind_of Response, response

      # Makes it easier to fill in cert sheet if you print these to the command line
      # puts "Auth/Resp Code => " + (response.params["auth_code"] || response.params["resp_code"])
      # puts "AVS Resp => " + response.params["avs_resp_code"]
      # puts "CVD Resp => " + response.params["cvv2_resp_code"]
      # puts "TxRefNum => " + response.params["tx_ref_num"]
      # puts
    end
  end

  # ==== Section B
  def test_auth_capture_transactions
    for suite in @test_suite do
      amount = suite[:amount]
      card = credit_card(@cards[suite[:card]], verification_value: suite[:CVD])
      options = @options; options[:address][:zip] = suite[:AVSzip]
      assert response = @gateway.purchase(amount, card, options)
      assert_kind_of Response, response

      # Makes it easier to fill in cert sheet if you print these to the command line
      # puts "Auth/Resp Code => " + (response.params["auth_code"] || response.params["resp_code"])
      # puts "AVS Resp => " + response.params["avs_resp_code"]
      # puts "CVD Resp => " + response.params["cvv2_resp_code"]
      # puts "TxRefNum => " + response.params["tx_ref_num"]
      # puts
    end
  end

  # ==== Section C
  def test_mark_for_capture_transactions
    [[:visa, 3000], [:mc, 4100], [:amex, 105500], [:ds, 1000], [:jcb, 2900]].each do |suite|
      amount = suite[1]
      card = credit_card(@cards[suite[0]])
      assert auth_response = @gateway.authorize(amount, card, @options)
      assert capt_response = @gateway.capture(amount, auth_response.authorization)
      assert_kind_of Response, capt_response

      # Makes it easier to fill in cert sheet if you print these to the command line
      # puts "Auth/Resp Code => " + (auth_response.params["auth_code"] || auth_response.params["resp_code"])
      # puts "TxRefNum => " + capt_response.params["tx_ref_num"]
      # puts
    end
  end

  # ==== Section D
  def test_refund_transactions
    [[:visa, 1200], [:mc, 1100], [:amex, 105500], [:ds, 1000], [:jcb, 2900]].each do |suite|
      amount = suite[1]
      card = credit_card(@cards[suite[0]])
      assert purchase_response = @gateway.purchase(amount, card, @options)
      assert refund_response = @gateway.refund(amount, purchase_response.authorization, @options)
      assert_kind_of Response, refund_response

      # Makes it easier to fill in cert sheet if you print these to the command line
      # puts "Auth/Resp Code => " + (purchase_response.params["auth_code"] || purchase_response.params["resp_code"])
      # puts "TxRefNum => " + credit_response.params["tx_ref_num"]
      # puts
    end
  end

  # ==== Section F
  def test_void_transactions
    [3000, 105500, 2900].each do |amount|
      assert auth_response = @gateway.authorize(amount, @credit_card, @options)
      assert void_response = @gateway.void(auth_response.authorization, @options.merge(transaction_index: 1))
      assert_kind_of Response, void_response

      # Makes it easier to fill in cert sheet if you print these to the command line
      # puts "TxRefNum => " + void_response.params["tx_ref_num"]
      # puts
    end
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_failed_verify
    response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_equal 'Invalid CC Number', response.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:password], transcript)
    assert_scrubbed(@gateway.options[:login], transcript)
    assert_scrubbed(@gateway.options[:merchant_id], transcript)
  end

  def test_transcript_scrubbing_profile
    transcript = capture_transcript(@gateway) do
      @gateway.add_customer_profile(@credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:password], transcript)
    assert_scrubbed(@gateway.options[:login], transcript)
    assert_scrubbed(@gateway.options[:merchant_id], transcript)
  end

  private

  def stored_credential_options(*args, id: nil)
    @options.merge(order_id: generate_unique_id,
                   stored_credential: stored_credential(*args, id: id))
  end
end
