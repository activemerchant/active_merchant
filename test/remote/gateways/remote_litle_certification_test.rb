require 'test_helper'

class RemoteLitleCertification < Test::Unit::TestCase
  def setup
    Base.mode = :test
    @gateway = LitleGateway.new(fixtures(:litle))
    @gateway.test_url = "https://payments.vantivprelive.com/vap/communicator/online"
  end

  def test1
    credit_card = CreditCard.new(
      :number => '4457010000000009',
      :month => '01',
      :year => '2021',
      :verification_value => '349',
      :brand => 'visa'
    )

    options = {
      :order_id => '1',
      :billing_address => {
        :name => 'John & Mary Smith',
        :address1 => '1 Main St.',
        :city => 'Burlington',
        :state => 'MA',
        :zip => '01803-3747',
        :country => 'US'
      }
    }

    auth_assertions(10100, credit_card, options, :avs => "X", :cvv => "M")

    authorize_avs_assertions(credit_card, options, :avs => "X", :cvv => "M")

    sale_assertions(10100, credit_card, options, :avs => "X", :cvv => "M")
  end

  def test2
    credit_card = CreditCard.new(:number => '5112010000000003', :month => '02',
                                 :year => '2021', :brand => 'master',
                                 :verification_value => '261',
                                 :name => 'Mike J. Hammer')

    options = {
      :order_id => '2',
      :billing_address => {
        :address1 => '2 Main St.',
        :address2 => 'Apt. 222',
        :city => 'Riverside',
        :state => 'RI',
        :zip => '02915',
        :country => 'US'
      }
    }

    auth_assertions(10100, credit_card, options, :avs => "Z", :cvv => "M")

    authorize_avs_assertions(credit_card, options, :avs => "Z", :cvv => "M")

    sale_assertions(10100, credit_card, options, :avs => "Z", :cvv => "M")
  end

  def test3
    credit_card = CreditCard.new(
      :number => '6011010000000003',
      :month => '03',
      :year => '2021',
      :verification_value => '758',
      :brand => 'discover'
    )

    options = {
      :order_id => '3',
      :billing_address => {
        :name => 'Eileen Jones',
        :address1 => '3 Main St.',
        :city => 'Bloomfield',
        :state => 'CT',
        :zip => '06002',
        :country => 'US'
      }
    }
    auth_assertions(10100, credit_card, options, :avs => "Z", :cvv => "M")

    authorize_avs_assertions(credit_card, options, :avs => "Z", :cvv => "M")

    sale_assertions(10100, credit_card, options, :avs => "Z", :cvv => "M")
  end

  def test4
    credit_card = CreditCard.new(
      :number => '375001000000005',
      :month => '04',
      :year => '2021',
      :brand => 'american_express'
    )

    options = {
      :order_id => '4',
      :billing_address => {
        :name => 'Bob Black',
        :address1 => '4 Main St.',
        :city => 'Laurel',
        :state => 'MD',
        :zip => '20708',
        :country => 'US'
      }
    }

    auth_assertions(10100, credit_card, options, :avs => "A", :cvv => nil)

    authorize_avs_assertions(credit_card, options, :avs => "A")

    sale_assertions(10100, credit_card, options, :avs => "A", :cvv => nil)
  end

  def test5
    credit_card = ActiveMerchant::Billing::NetworkTokenizationCreditCard.new(
      :number => '4100200300011001',
      :month => '05',
      :year => '2021',
      :verification_value => '463',
      :brand => 'visa',
      :payment_cryptogram => 'BwABBJQ1AgAAAAAgJDUCAAAAAAA='
    )

    options = {
      :order_id => '5'
    }

    auth_assertions(10100, credit_card, options, :avs => "U", :cvv => "M")

    authorize_avs_assertions(credit_card, options, :avs => "U", :cvv => "M")

    sale_assertions(10100, credit_card, options, :avs => "U", :cvv => "M")
  end

  def test6
    credit_card = CreditCard.new(:number => '4457010100000008', :month => '06',
                                 :year => '2021', :brand => 'visa',
                                 :verification_value => '992')

    options = {
      :order_id => '6',
      :billing_address => {
        :name => 'Joe Green',
        :address1 => '6 Main St.',
        :city => 'Derry',
        :state => 'NH',
        :zip => '03038',
        :country => 'US'
      }
    }

    # 6: authorize
    assert response = @gateway.authorize(10100, credit_card, options)
    assert !response.success?
    assert_equal '110', response.params['response']
    assert_equal 'Insufficient Funds', response.message
    assert_equal "I", response.avs_result["code"]
    assert_equal "P", response.cvv_result["code"]
    puts "Test #{options[:order_id]} Authorize: #{txn_id(response)}"

    # 6. sale
    assert response = @gateway.purchase(10100, credit_card, options)
    assert !response.success?
    assert_equal '110', response.params['response']
    assert_equal 'Insufficient Funds', response.message
    assert_equal "I", response.avs_result["code"]
    assert_equal "P", response.cvv_result["code"]
    puts "Test #{options[:order_id]} Sale: #{txn_id(response)}"


    # 6A. void
    assert response = @gateway.void(response.authorization, {:order_id => '6A'})
    assert_equal '360', response.params['response']
    assert_equal 'No transaction found with specified transaction Id', response.message
    puts "Test #{options[:order_id]}A: #{txn_id(response)}"

  end

  def test7
    credit_card = CreditCard.new(:number => '5112010100000002', :month => '07',
                                 :year => '2021', :brand => 'master',
                                 :verification_value => '251')

    options = {
      :order_id => '7',
      :billing_address => {
        :name => 'Jane Murray',
        :address1 => '7 Main St.',
        :city => 'Amesbury',
        :state => 'MA',
        :zip => '01913',
        :country => 'US'
      }
    }

    # 7: authorize
    assert response = @gateway.authorize(10100, credit_card, options)
    assert !response.success?
    assert_equal '301', response.params['response']
    assert_equal 'Invalid Account Number', response.message
    assert_equal "I", response.avs_result["code"]
    assert_equal "N", response.cvv_result["code"]
    puts "Test #{options[:order_id]} Authorize: #{txn_id(response)}"

    # 7: authorize avs
    authorize_avs_assertions(credit_card, options, :avs => "I", :cvv => "N", :message => "Invalid Account Number", :success => false)

    # 7. sale
    assert response = @gateway.purchase(10100, credit_card, options)
    assert !response.success?
    assert_equal '301', response.params['response']
    assert_equal 'Invalid Account Number', response.message
    assert_equal "I", response.avs_result["code"]
    assert_equal "N", response.cvv_result["code"]
    puts "Test #{options[:order_id]} Sale: #{txn_id(response)}"
  end

  def test8
    credit_card = CreditCard.new(:number => '6011010100000002', :month => '08',
                                 :year => '2021', :brand => 'discover',
                                 :verification_value => '184')

    options = {
      :order_id => '8',
      :billing_address => {
        :name => 'Mark Johnson',
        :address1 => '8 Main St.',
        :city => 'Manchester',
        :state => 'NH',
        :zip => '03101',
        :country => 'US'
      }
    }

    # 8: authorize
    assert response = @gateway.authorize(10100, credit_card, options)
    assert !response.success?
    assert_equal '123', response.params['response']
    assert_equal 'Call Discover', response.message
    assert_equal "I", response.avs_result["code"]
    assert_equal "P", response.cvv_result["code"]
    puts "Test #{options[:order_id]} Authorize: #{txn_id(response)}"

    # 8: authorize avs
    authorize_avs_assertions(credit_card, options, :avs => "I", :cvv => "P", :message => "Call Discover", :success => false)

    # 8: sale
    assert response = @gateway.purchase(80080, credit_card, options)
    assert !response.success?
    assert_equal '123', response.params['response']
    assert_equal 'Call Discover', response.message
    assert_equal "I", response.avs_result["code"]
    assert_equal "P", response.cvv_result["code"]
    puts "Test #{options[:order_id]} Sale: #{txn_id(response)}"
  end

  def test9
    credit_card = CreditCard.new(:number => '375001010000003', :month => '09',
                                 :year => '2021', :brand => 'american_express',
                                 :verification_value => '0421')

    options = {
      :order_id => '9',
      :billing_address => {
        :name => 'James Miller',
        :address1 => '9 Main St.',
        :city => 'Boston',
        :state => 'MA',
        :zip => '02134',
        :country => 'US'
      }
    }

    # 9: authorize
    assert response = @gateway.authorize(10100, credit_card, options)
    assert !response.success?
    assert_equal '303', response.params['response']
    assert_equal 'Pick Up Card', response.message
    assert_equal "I", response.avs_result["code"]
    puts "Test #{options[:order_id]} Authorize: #{txn_id(response)}"

    # 9: authorize avs
    authorize_avs_assertions(credit_card, options, :avs => "I", :message => "Pick Up Card", :success => false)

    # 9: sale
    assert response = @gateway.purchase(10100, credit_card, options)
    assert !response.success?
    assert_equal '303', response.params['response']
    assert_equal 'Pick Up Card', response.message
    assert_equal "I", response.avs_result["code"]
    puts "Test #{options[:order_id]} Sale: #{txn_id(response)}"
  end

  # Authorization Reversal Tests
  def test32
    credit_card = CreditCard.new(:number => '4457010000000009', :month => '01',
                                 :year => '2021', :brand => 'visa',
                                 :verification_value => '349')

    options = {
      :order_id => '32',
      :billing_address => {
        :name => 'John Smith',
        :address1 => '1 Main St.',
        :city => 'Burlington',
        :state => 'MA',
        :zip => '01803-3747',
        :country => 'US'
      }
    }

    assert auth_response = @gateway.authorize(10010, credit_card, options)
    assert_success auth_response
    assert_equal '11111 ', auth_response.params['authCode']
    puts "Test #{options[:order_id]}: #{txn_id(auth_response)}"

    assert capture_response = @gateway.capture(5050, auth_response.authorization, options)
    assert_success capture_response
    puts "Test #{options[:order_id]}A: #{txn_id(capture_response)}"

    assert reversal_response = @gateway.void(auth_response.authorization, options)
    assert_failure reversal_response
    assert 'Authorization amount has already been depleted', reversal_response.message
    puts "Test #{options[:order_id]}B: #{txn_id(reversal_response)}"
  end

  def test33
    credit_card = CreditCard.new(:number => '5112010000000003', :month => '01',
                                 :year => '2021', :brand => 'master',
                                 :verification_value => '261')

    options = {
      :order_id => '33',
      :billing_address => {
        :name => 'Mike J. Hammer',
        :address1 => '2 Main St.',
        :address2 => 'Apt. 222',
        :city => 'Riverside',
        :state => 'RI',
        :zip => '02915',
        :country => 'US',
        :payment_cryptogram => 'BwABBJQ1AgAAAAAgJDUCAAAAAAA='
      }
    }

    assert auth_response = @gateway.authorize(20020, credit_card, options)
    assert_success auth_response
    assert_equal '22222 ', auth_response.params['authCode']
    puts "Test #{options[:order_id]}: #{txn_id(auth_response)}"

    assert reversal_response = @gateway.void(auth_response.authorization, options)
    assert_success reversal_response
    puts "Test #{options[:order_id]}A: #{txn_id(reversal_response)}"
  end

  def test34
    credit_card = CreditCard.new(:number => '6011010000000003', :month => '01',
                                 :year => '2021', :brand => 'discover',
                                 :verification_value => '758')

    options = {
      :order_id => '34',
      :billing_address => {
        :name => 'Eileen Jones',
        :address1 => '3 Main St.',
        :city => 'Bloomfield',
        :state => 'CT',
        :zip => '06002',
        :country => 'US'
      }
    }

    assert auth_response = @gateway.authorize(30030, credit_card, options)
    assert_success auth_response
    assert '33333 ', auth_response.params['authCode']
    puts "Test #{options[:order_id]}: #{txn_id(auth_response)}"

    assert reversal_response = @gateway.void(auth_response.authorization, options)
    assert_success reversal_response
    puts "Test #{options[:order_id]}A: #{txn_id(reversal_response)}"
  end

  def test35
    credit_card = CreditCard.new(:number => '375001000000005', :month => '01',
                                 :year => '2021', :brand => 'american_express')

    options = {
      :order_id => '35',
      :billing_address => {
        :name => 'Bob Black',
        :address1 => '4 Main St.',
        :city => 'Laurel',
        :state => 'MD',
        :zip => '20708',
        :country => 'US'
      }
    }

    assert auth_response = @gateway.authorize(10100, credit_card, options)
    assert_success auth_response
    assert_equal '44444 ', auth_response.params['authCode']
    assert_equal 'A', auth_response.avs_result["code"]
    puts "Test #{options[:order_id]}: #{txn_id(auth_response)}"

    assert capture_response = @gateway.capture(5050, auth_response.authorization, options)
    assert_success capture_response
    puts "Test #{options[:order_id]}A: #{txn_id(capture_response)}"

    assert reversal_response = @gateway.void(auth_response.authorization, options)
    assert_failure reversal_response
    assert 'Reversal amount does not match Authorization amount', reversal_response.message
    puts "Test #{options[:order_id]}B: #{txn_id(reversal_response)}"
  end

  def test36
    credit_card = CreditCard.new(:number => '375000026600004', :month => '01',
                                 :year => '2021', :brand => 'american_express')

    options = {
      :order_id => '36'
      }

    assert auth_response = @gateway.authorize(20500, credit_card, options)
    assert_success auth_response
    puts "Test #{options[:order_id]}: #{txn_id(auth_response)}"

    assert reversal_response = @gateway.void(auth_response.authorization, options)
    assert_failure reversal_response
    assert 'Reversal amount does not match Authorization amount', reversal_response.message
    puts "Test #{options[:order_id]}A: #{txn_id(reversal_response)}"
  end

  # Explicit Token Registration Tests
  def test50
    credit_card = CreditCard.new(:number => '4457119922390123')
    options     = {
      :order_id => '50'
    }

    # store
    store_response = @gateway.store(credit_card, options)

    assert_success store_response
    assert_equal '445711', store_response.params['bin']
    assert_equal 'VI', store_response.params['type']
    assert_equal '0123', store_response.params['litleToken'][-4,4]
    assert_equal '801', store_response.params['response']
    assert_equal 'Account number was successfully registered', store_response.message
    puts "Test #{options[:order_id]}: #{txn_id(response)}"
  end

  def test51
    credit_card = CreditCard.new(:number => '4457119999999999')
    options = {
      :order_id => '51'
    }

    # store
    store_response = @gateway.store(credit_card, options)

    assert_failure store_response
    assert_equal 'Credit card number was invalid', store_response.message
    assert_equal '820', store_response.params['response']
    assert_equal nil, store_response.params['litleToken']
  end

  def test52
    credit_card = CreditCard.new(:number => '4457119922390123')
    options = {
      :order_id => '52'
    }

    # store
    store_response = @gateway.store(credit_card, options)

    assert_success store_response
    assert_equal 'Account number was previously registered', store_response.message
    assert_equal '445711', store_response.params['bin']
    assert_equal 'VI', store_response.params['type']
    assert_equal '802', store_response.params['response']
    assert_equal '0123', store_response.params['litleToken'][-4,4]
    puts "Test #{options[:order_id]}: #{txn_id(store_response)}"
  end

  # Implicit Token Registration Tests
  def test55
    credit_card = CreditCard.new(:number             => '5435101234510196',
                                 :month              => '11',
                                 :year               => '2014',
                                 :brand              => 'master',
                                 :verification_value => '987')
    options = {
      :order_id => '55'
    }

    # authorize
    assert response = @gateway.authorize(15000, credit_card, options)
    assert_success response
    assert_equal 'Approved', response.message
    assert_equal '0196', response.params['tokenResponse_litleToken'][-4,4]
    assert %w(801 802).include? response.params['tokenResponse_tokenResponseCode']
    assert_equal 'MC', response.params['tokenResponse_type']
    assert_equal '543510', response.params['tokenResponse_bin']
    puts "Test #{options[:order_id]}: #{txn_id(response)}"
  end

  def test56
    credit_card = CreditCard.new(:number             => '5435109999999999',
                                 :month              => '11',
                                 :year               => '2014',
                                 :brand              => 'master',
                                 :verification_value => '987')
    options = {
      :order_id => '56'
    }

    # authorize
    assert response = @gateway.authorize(15000, credit_card, options)

    assert_failure response
    assert_equal '301', response.params['response']
    puts "Test #{options[:order_id]}: #{txn_id(response)}"
  end

  def test57_58
    credit_card = CreditCard.new(:number             => '5435101234510196',
                                 :month              => '11',
                                 :year               => '2014',
                                 :brand              => 'master',
                                 :verification_value => '987')
    options = {
      :order_id => '57'
    }

    # authorize card
    assert response = @gateway.authorize(15000, credit_card, options)

    assert_success response
    assert_equal 'Approved', response.message
    assert_equal '0196', response.params['tokenResponse_litleToken'][-4,4]
    assert %w(801 802).include? response.params['tokenResponse_tokenResponseCode']
    assert_equal 'MC', response.params['tokenResponse_type']
    assert_equal '543510', response.params['tokenResponse_bin']
    puts "Test #{options[:order_id]}: #{txn_id(response)}"

    # authorize token
    token   = response.params['tokenResponse_litleToken']
    options = {
      :order_id => '58',
      :token    => {
        :month => credit_card.month,
        :year  => credit_card.year
      }
    }

    # authorize
    assert response = @gateway.authorize(15000, token, options)

    assert_success response
    assert_equal 'Approved', response.message
    puts "Test #{options[:order_id]}: #{txn_id(response)}"
  end

  def test59
    token   = '1111000100092332'
    options = {
      :order_id => '59',
      :token    => {
        :month => '11',
        :year  => '2021'
      }
    }

    # authorize
    assert response = @gateway.authorize(15000, token, options)

    assert_failure response
    assert_equal '822', response.params['response']
    assert_equal 'Token was not found', response.message
    puts "Test #{options[:order_id]}: #{txn_id(response)}"
  end

  def test60
    token   = '171299999999999'
    options = {
      :order_id => '60',
      :token    => {
        :month => '11',
        :year  => '2014'
      }
    }

    # authorize
    assert response = @gateway.authorize(15000, token, options)

    assert_failure response
    assert_equal '823', response.params['response']
    assert_equal 'Token was invalid', response.message
    puts "Test #{options[:order_id]}: #{txn_id(response)}"
  end

  def test_apple_pay_purchase
    options = {
      :order_id => transaction_id,
    }
    decrypted_apple_pay = ActiveMerchant::Billing::NetworkTokenizationCreditCard.new(
      {
        month: '01',
        year: '2021',
        brand: "visa",
        number:  "4457000300000007",
        payment_cryptogram: "BwABBJQ1AgAAAAAgJDUCAAAAAAA="
      })

    assert response = @gateway.purchase(10010, decrypted_apple_pay, options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_android_pay_purchase
    options = {
      :order_id => transaction_id,
    }
    decrypted_android_pay = ActiveMerchant::Billing::NetworkTokenizationCreditCard.new(
      {
        source: :android_pay,
        month: '01',
        year: '2021',
        brand: "visa",
        number:  "4457000300000007",
        payment_cryptogram: "BwABBJQ1AgAAAAAgJDUCAAAAAAA="
      })

    assert response = @gateway.purchase(10010, decrypted_android_pay, options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_three_d_secure
    three_d_secure_assertions('3DS1', '4100200300000004', 'visa', '3dsAuthenticated', '0')
    three_d_secure_assertions('3DS2', '4100200300000012', 'visa', '3dsAuthenticated', '1')
    three_d_secure_assertions('3DS3', '4100200300000103', 'visa', '3dsAuthenticated', '2')
    three_d_secure_assertions('3DS4', '4100200300001002', 'visa', '3dsAuthenticated', 'A')
    three_d_secure_assertions('3DS5', '4100200300000020', 'visa', '3dsAuthenticated', '3')
    three_d_secure_assertions('3DS6', '4100200300000038', 'visa', '3dsAuthenticated', '4')
    three_d_secure_assertions('3DS7', '4100200300000046', 'visa', '3dsAuthenticated', '5')
    three_d_secure_assertions('3DS8', '4100200300000053', 'visa', '3dsAuthenticated', '6')
    three_d_secure_assertions('3DS9', '4100200300000061', 'visa', '3dsAuthenticated', '7')
    three_d_secure_assertions('3DS10', '4100200300000079', 'visa', '3dsAuthenticated', '8')
    three_d_secure_assertions('3DS11', '4100200300000087', 'visa', '3dsAuthenticated', '9')
    three_d_secure_assertions('3DS12', '4100200300000095', 'visa', '3dsAuthenticated', 'B')
    three_d_secure_assertions('3DS13', '4100200300000111', 'visa', '3dsAuthenticated', 'C')
    three_d_secure_assertions('3DS14', '4100200300000129', 'visa', '3dsAuthenticated', 'D')
    three_d_secure_assertions('3DS15', '5112010200000001', 'master', '3dsAttempted', nil)
    three_d_secure_assertions('3DS16', '5112010200000001', 'master', '3dsAttempted', nil)
  end

  def test_authorize_and_purchase_and_credit_with_token
    options = {
      :order_id => transaction_id,
      :billing_address => {
        :name => 'John Smith',
        :address1 => '1 Main St.',
        :city => 'Burlington',
        :state => 'MA',
        :zip => '01803-3747',
        :country => 'US'
      }
    }

    credit_card = CreditCard.new(:number             => '5435101234510196',
                                 :month              => '11',
                                 :year               => '2014',
                                 :brand              => 'master',
                                 :verification_value => '987')

    # authorize
    assert auth_response = @gateway.authorize(0, credit_card, options)

    assert_success auth_response
    assert_equal 'Approved', auth_response.message
    token = auth_response.params['litleOnlineResponse']['authorizationResponse']['tokenResponse']['litleToken']
    assert_equal '0196', token[-4, 4]
    assert %w(801 802).include? auth_response.params['litleOnlineResponse']['authorizationResponse']['tokenResponse']['tokenResponseCode']

    # purchase
    purchase_options = options.merge({
                                         :order_id => transaction_id,
                                         :token    => {
                                             :month => credit_card.month,
                                             :year  => credit_card.year
                                         }
                                     })

    assert purchase_response = @gateway.purchase(100, token, purchase_options)
    assert_success purchase_response
    assert_equal 'Approved', purchase_response.message
    assert_equal purchase_options[:order_id], purchase_response.params['litleOnlineResponse']['saleResponse']['id']

    # credit
    credit_options = options.merge({
                                       :order_id => transaction_id,
                                       :token    => {
                                           :month => credit_card.month,
                                           :year  => credit_card.year
                                       }
                                   })

    assert credit_response = @gateway.credit(500, token, credit_options)
    assert_success credit_response
    assert_equal 'Approved', credit_response.message
    assert_equal credit_options[:order_id], credit_response.params['litleOnlineResponse']['creditResponse']['id']
  end

  private

  def auth_assertions(amount, card, options, assertions={})
    # 1: authorize
    assert response = @gateway.authorize(amount, card, options)
    assert_success response
    assert_equal 'Approved', response.message
    assert_equal assertions[:avs], response.avs_result["code"] if assertions[:avs]
    assert_equal assertions[:cvv], response.cvv_result["code"] if assertions[:cvv]
    assert_equal auth_code(options[:order_id]), response.params['authCode']
    puts "Test #{options[:order_id]} Authorize: #{txn_id(response)}"

    # 1A: capture
    assert response = @gateway.capture(amount, response.authorization, {:id => transaction_id})
    assert_equal 'Approved', response.message
    puts "Test #{options[:order_id]}A: #{txn_id(response)}"

    # 1B: credit
    assert response = @gateway.credit(amount, response.authorization, {:id => transaction_id})
    assert_equal 'Approved', response.message
    puts "Test #{options[:order_id]}B: #{txn_id(response)}"

    # 1C: void
    assert response = @gateway.void(response.authorization, {:id => transaction_id})
    assert_equal 'Approved', response.message
    puts "Test #{options[:order_id]}C: #{txn_id(response)}"
  end

  def authorize_avs_assertions(credit_card, options, assertions={})
    assert response = @gateway.authorize(000, credit_card, options)
    assert_equal assertions.key?(:success) ? assertions[:success] : true, response.success?
    assert_equal assertions[:message] || 'Approved', response.message
    assert_equal assertions[:avs], response.avs_result["code"], caller.inspect
    assert_equal assertions[:cvv], response.cvv_result["code"], caller.inspect if assertions[:cvv]
    puts "Test #{options[:order_id]} AVS Only: #{txn_id(response)}"
  end

  def sale_assertions(amount, card, options, assertions={})
    # 1: sale
    assert response = @gateway.purchase(amount, card, options)
    assert_success response
    assert_equal 'Approved', response.message
    assert_equal assertions[:avs], response.avs_result["code"] if assertions[:avs]
    assert_equal assertions[:cvv], response.cvv_result["code"] if assertions[:cvv]
    assert_equal auth_code(options[:order_id]), response.params['authCode']
    puts "Test #{options[:order_id]} Sale: #{txn_id(response)}"


    # 1B: credit
    assert response = @gateway.credit(amount, response.authorization, {:id => transaction_id})
    assert_equal 'Approved', response.message
    puts "Test #{options[:order_id]}B Sale: #{txn_id(response)}"

    # 1C: void
    assert response = @gateway.void(response.authorization, {:id => transaction_id})
    assert_equal 'Approved', response.message
    puts "Test #{options[:order_id]}C Sale: #{txn_id(response)}"
  end

  def auth_assertions(amount, card, options, assertions={})
    # 1: authorize
    assert response = @gateway.authorize(amount, card, options)
    assert_success response
    assert_equal 'Approved', response.message
    assert_equal assertions[:avs], response.avs_result["code"] if assertions[:avs]
    assert_equal assertions[:cvv], response.cvv_result["code"] if assertions[:cvv]
    assert_equal auth_code(options[:order_id]), response.params['authCode']

    # 1A: capture
    assert response = @gateway.capture(amount, response.authorization, {:id => transaction_id})
    assert_equal 'Approved', response.message

    # 1B: credit
    assert response = @gateway.credit(amount, response.authorization, {:id => transaction_id})
    assert_equal 'Approved', response.message

    # 1C: void
    assert response = @gateway.void(response.authorization, {:id => transaction_id})
    assert_equal 'Approved', response.message
  end

  def authorize_avs_assertions(credit_card, options, assertions={})
    assert response = @gateway.authorize(000, credit_card, options)
    assert_equal assertions.key?(:success) ? assertions[:success] : true, response.success?
    assert_equal assertions[:message] || 'Approved', response.message
    assert_equal assertions[:avs], response.avs_result["code"], caller.inspect
    assert_equal assertions[:cvv], response.cvv_result["code"], caller.inspect if assertions[:cvv]
  end

  def sale_assertions(amount, card, options, assertions={})
    # 1: sale
    assert response = @gateway.purchase(amount, card, options)
    assert_success response
    assert_equal 'Approved', response.message
    assert_equal assertions[:avs], response.avs_result["code"] if assertions[:avs]
    assert_equal assertions[:cvv], response.cvv_result["code"] if assertions[:cvv]
    # assert_equal auth_code(options[:order_id]), response.params['authCode']

    # 1B: credit
    assert response = @gateway.credit(amount, response.authorization, {:id => transaction_id})
    assert_equal 'Approved', response.message

    # 1C: void
    assert response = @gateway.void(response.authorization, {:id => transaction_id})
    assert_equal 'Approved', response.message
  end

  def three_d_secure_assertions(test_id, card, type, source, result)
    credit_card = CreditCard.new(:number => card, :month => '01',
                                 :year => '2021', :brand => type,
                                 :verification_value => '261',
                                 :name => 'Mike J. Hammer')

    options = {
      order_id: test_id,
      order_source: source,
      cavv: 'BwABBJQ1AgAAAAAgJDUCAAAAAAA=',
      xid: 'BwABBJQ1AgAAAAAgJDUCAAAAAAA='
    }

    assert response = @gateway.authorize(10100, credit_card, options)
    assert_success response
    assert_equal result, response.params['fraudResult_authenticationResult']
    puts "Test #{test_id}: #{txn_id(response)}"
  end

  def transaction_id
    # A unique identifier assigned by the presenter and mirrored back in the response.
    # This attribute is also used for Duplicate Transaction Detection.
    # For Online transactions, omitting this attribute, or setting it to a
    # null value (id=""), disables Duplicate Detection for the transaction.
    #
    # minLength = N/A   maxLength = 25
    generate_unique_id[0, 24]
  end

  def auth_code(order_id)
    order_id * 5 + ' '
  end

  def txn_id(response)
    response.authorization.split(";")[0]
  end
end
