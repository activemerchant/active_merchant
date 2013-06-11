require 'test_helper'

class RemoteLitleCertification < Test::Unit::TestCase
  def setup
    Base.gateway_mode = :test
    @gateway = LitleGateway.new(fixtures(:litle).merge(:url => "https://cert.litle.com/vap/communicator/online"))
  end

  def test1
    credit_card = CreditCard.new(
      :number => '4457010000000009',
      :month => '01',
      :year => '2014',
      :verification_value => '349',
      :brand => 'visa'
    )

    options = {
      :order_id => '1',
      :billing_address => {
        :name => 'John Smith',
        :address1 => '1 Main St.',
        :city => 'Burlington',
        :state => 'MA',
        :zip => '01803-3747',
        :country => 'US'
      }
    }

    auth_assertions(10010, credit_card, options, :avs => "X", :cvv => "M")

    # 1: authorize avs
    authorize_avs_assertions(credit_card, options, :avs => "X", :cvv => "M")

    sale_assertions(10010, credit_card, options, :avs => "X", :cvv => "M")
  end

  def test2
    credit_card = CreditCard.new(:number => '5112010000000003', :month => '02',
                                 :year => '2014', :brand => 'master',
                                 :verification_value => '261')

    options = {
      :order_id => '2',
      :billing_address => {
        :name => 'Mike J. Hammer',
        :address1 => '2 Main St.',
        :city => 'Riverside',
        :state => 'RI',
        :zip => '02915',
        :country => 'US'
      }
    }

    auth_assertions(20020, credit_card, options, :avs => "Z", :cvv => "M")

    # 2: authorize avs
    authorize_avs_assertions(credit_card, options, :avs => "Z", :cvv => "M")

    sale_assertions(20020, credit_card, options, :avs => "Z", :cvv => "M")
  end

  def test3
    credit_card = CreditCard.new(
      :number => '6011010000000003',
      :month => '03',
      :year => '2014',
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
    auth_assertions(30030, credit_card, options, :avs => "Z", :cvv => "M")

    # 3: authorize avs
    authorize_avs_assertions(credit_card, options, :avs => "Z", :cvv => "M")

    sale_assertions(30030, credit_card, options, :avs => "Z", :cvv => "M")
  end

  def test4
    credit_card = CreditCard.new(
      :number => '375001000000005',
      :month => '04',
      :year => '2014',
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

    auth_assertions(40040, credit_card, options, :avs => "A", :cvv => nil)

    # 4: authorize avs
    authorize_avs_assertions(credit_card, options, :avs => "A")

    sale_assertions(40040, credit_card, options, :avs => "A", :cvv => nil)
  end

  def test6
    credit_card = CreditCard.new(:number => '4457010100000008', :month => '06',
                                 :year => '2014', :brand => 'visa',
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
    assert response = @gateway.authorize(60060, credit_card, options)
    assert !response.success?
    assert_equal '110', response.params['litleOnlineResponse']['authorizationResponse']['response']
    assert_equal 'Insufficient Funds', response.message
    assert_equal "I", response.avs_result["code"]
    assert_equal "P", response.cvv_result["code"]

    # 6. sale
    assert response = @gateway.purchase(60060, credit_card, options)
    assert !response.success?
    assert_equal '110', response.params['litleOnlineResponse']['saleResponse']['response']
    assert_equal 'Insufficient Funds', response.message
    assert_equal "I", response.avs_result["code"]
    assert_equal "P", response.cvv_result["code"]

    # 6A. void
    assert response = @gateway.void(response.authorization, {:order_id => '6A'})
    assert_equal '360', response.params['litleOnlineResponse']['voidResponse']['response']
    assert_equal 'No transaction found with specified litleTxnId', response.message
  end

  def test7
    credit_card = CreditCard.new(:number => '5112010100000002', :month => '07',
                                 :year => '2014', :brand => 'master',
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
    assert response = @gateway.authorize(70070, credit_card, options)
    assert !response.success?
    assert_equal '301', response.params['litleOnlineResponse']['authorizationResponse']['response']
    assert_equal 'Invalid Account Number', response.message
    assert_equal "I", response.avs_result["code"]
    assert_equal "N", response.cvv_result["code"]

    # 7: authorize avs
    authorize_avs_assertions(credit_card, options, :avs => "I", :cvv => "N", :message => "Invalid Account Number", :success => false)

    # 7. sale
    assert response = @gateway.purchase(70070, credit_card, options)
    assert !response.success?
    assert_equal '301', response.params['litleOnlineResponse']['saleResponse']['response']
    assert_equal 'Invalid Account Number', response.message
    assert_equal "I", response.avs_result["code"]
    assert_equal "N", response.cvv_result["code"]
  end

  def test8
    credit_card = CreditCard.new(:number => '6011010100000002', :month => '08',
                                 :year => '2014', :brand => 'discover',
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
    assert response = @gateway.authorize(80080, credit_card, options)
    assert !response.success?
    assert_equal '123', response.params['litleOnlineResponse']['authorizationResponse']['response']
    assert_equal 'Call Discover', response.message
    assert_equal "I", response.avs_result["code"]
    assert_equal "P", response.cvv_result["code"]

    # 8: authorize avs
    authorize_avs_assertions(credit_card, options, :avs => "I", :cvv => "P", :message => "Call Discover", :success => false)

    # 8: sale
    assert response = @gateway.purchase(80080, credit_card, options)
    assert !response.success?
    assert_equal '123', response.params['litleOnlineResponse']['saleResponse']['response']
    assert_equal 'Call Discover', response.message
    assert_equal "I", response.avs_result["code"]
    assert_equal "P", response.cvv_result["code"]
  end

  def test9
    credit_card = CreditCard.new(:number => '375001010000003', :month => '09',
                                 :year => '2014', :brand => 'american_express',
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
    assert response = @gateway.authorize(90090, credit_card, options)

    assert !response.success?
    assert_equal '303', response.params['litleOnlineResponse']['authorizationResponse']['response']
    assert_equal 'Pick Up Card', response.message
    assert_equal "I", response.avs_result["code"]

    # 9: authorize avs
    authorize_avs_assertions(credit_card, options, :avs => "I", :message => "Pick Up Card", :success => false)

    # 9: sale
    assert response = @gateway.purchase(90090, credit_card, options)
    assert !response.success?
    assert_equal '303', response.params['litleOnlineResponse']['saleResponse']['response']
    assert_equal 'Pick Up Card', response.message
    assert_equal "I", response.avs_result["code"]
  end

  # Authorization Reversal Tests
  def test34
    credit_card = CreditCard.new(:number => '6011010000000003', :month => '03',
                                 :year => '2014', :brand => 'discover',
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

    credit_card = CreditCard.new(:number => '4024720001231239', :month => '12',
                                 :year => '2014', :brand => 'visa')
    assert auth_response2 = @gateway.authorize(18699, credit_card, :order_id => '29')

    assert reversal_response = @gateway.void(auth_response2.authorization)
    assert_success reversal_response
  end

  def test36
    options = {
        :order_id => '36'
    }

    credit_card = CreditCard.new(:number => '375000026600004', :month => '05',
                                 :year => '2014', :brand => 'american_express',
                                 :verification_value => '261')

    assert auth_response = @gateway.authorize(20500, credit_card, options)
    assert_success auth_response

    assert reversal_response = @gateway.void(auth_response.authorization, amount: 10000)
    assert !reversal_response.success?
    assert_equal '336', reversal_response.params['litleOnlineResponse']['authReversalResponse']['response']
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
    assert_equal 'Account number was successfully registered', store_response.message
    assert_equal '445711', store_response.params['litleOnlineResponse']['registerTokenResponse']['bin']
    assert_equal 'VI', store_response.params['litleOnlineResponse']['registerTokenResponse']['type'] #type is on Object in 1.8.7 - later versions can use .registerTokenResponse.type
    assert_equal '801', store_response.params['litleOnlineResponse']['registerTokenResponse']['response']
    assert_equal '0123', store_response.params['litleOnlineResponse']['registerTokenResponse']['litleToken'][-4,4]
  end

  def test51
    credit_card = CreditCard.new(:number => '4457119999999999')
    options     = {
        :order_id => '51'
    }

    # store
    store_response = @gateway.store(credit_card, options)

    assert_failure store_response
    assert_equal 'Credit card number was invalid', store_response.message
    assert_equal '820', store_response.params['litleOnlineResponse']['registerTokenResponse']['response']
    assert_equal nil, store_response.params['litleOnlineResponse']['registerTokenResponse']['litleToken']
  end

  def test52
    credit_card = CreditCard.new(:number => '4457119922390123')
    options     = {
        :order_id => '52'
    }

    # store
    store_response = @gateway.store(credit_card, options)

    assert_success store_response
    assert_equal 'Account number was previously registered', store_response.message
    assert_equal '445711', store_response.params['litleOnlineResponse']['registerTokenResponse']['bin']
    assert_equal 'VI', store_response.params['litleOnlineResponse']['registerTokenResponse']['type'] #type is on Object in 1.8.7 - later versions can use .registerTokenResponse.type
    assert_equal '802', store_response.params['litleOnlineResponse']['registerTokenResponse']['response']
    assert_equal '0123', store_response.params['litleOnlineResponse']['registerTokenResponse']['litleToken'][-4,4]
  end

  # Implicit Token Registration Tests
  def test55
    credit_card = CreditCard.new(:number             => '5435101234510196',
                                 :month              => '11',
                                 :year               => '2014',
                                 :brand              => 'master',
                                 :verification_value => '987')
    options     = {
        :order_id => '55'
    }

    # authorize
    assert response = @gateway.authorize(15000, credit_card, options)
    #"tokenResponse" => { "litleToken"        => "1712000118270196",
    #                     "tokenResponseCode" => "802",
    #                     "tokenMessage"      => "Account number was previously registered",
    #                     "type"              => "MC",
    #                     "bin"               => "543510" }
    assert_success response
    assert_equal 'Approved', response.message
    assert_equal '0196', response.params['litleOnlineResponse']['authorizationResponse']['tokenResponse']['litleToken'][-4,4]
    assert %w(801 802).include? response.params['litleOnlineResponse']['authorizationResponse']['tokenResponse']['tokenResponseCode']
    assert_equal 'MC', response.params['litleOnlineResponse']['authorizationResponse']['tokenResponse']['type']
    assert_equal '543510', response.params['litleOnlineResponse']['authorizationResponse']['tokenResponse']['bin']
  end

  def test56
    credit_card = CreditCard.new(:number             => '5435109999999999',
                                 :month              => '11',
                                 :year               => '2014',
                                 :brand              => 'master',
                                 :verification_value => '987')
    options     = {
        :order_id => '56'
    }

    # authorize
    assert response = @gateway.authorize(15000, credit_card, options)

    assert_failure response
    assert_equal '301', response.params['litleOnlineResponse']['authorizationResponse']['response']
  end

  def test57_58
    credit_card = CreditCard.new(:number             => '5435101234510196',
                                 :month              => '11',
                                 :year               => '2014',
                                 :brand              => 'master',
                                 :verification_value => '987')
    options     = {
        :order_id => '57'
    }

    # authorize card
    assert response = @gateway.authorize(15000, credit_card, options)

    assert_success response
    assert_equal 'Approved', response.message
    assert_equal '0196', response.params['litleOnlineResponse']['authorizationResponse']['tokenResponse']['litleToken'][-4,4]
    assert %w(801 802).include? response.params['litleOnlineResponse']['authorizationResponse']['tokenResponse']['tokenResponseCode']
    assert_equal 'MC', response.params['litleOnlineResponse']['authorizationResponse']['tokenResponse']['type']
    assert_equal '543510', response.params['litleOnlineResponse']['authorizationResponse']['tokenResponse']['bin']

    # authorize token
    token   = response.params['litleOnlineResponse']['authorizationResponse']['tokenResponse']['litleToken']
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
  end

  def test59
    token   = '1712990000040196'
    options = {
        :order_id => '59',
        :token    => {
            :month => '11',
            :year  => '2014'
        }
    }

    # authorize
    assert response = @gateway.authorize(15000, token, options)

    assert_failure response
    assert_equal '822', response.params['litleOnlineResponse']['authorizationResponse']['response']
    assert_equal 'Token was not found', response.message
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
    assert_equal '823', response.params['litleOnlineResponse']['authorizationResponse']['response']
    assert_equal 'Token was invalid', response.message
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

  def auth_assertions(amount, card, options, assertions)
    # 1: authorize
    assert response = @gateway.authorize(amount, card, options)
    assert_success response
    assert_equal 'Approved', response.message
    assert_equal assertions[:avs], response.avs_result["code"]
    assert_equal assertions[:cvv], response.cvv_result["code"] if assertions[:cvv]
    assert_equal options[:order_id], response.params['litleOnlineResponse']['authorizationResponse']['id']

    # 1A: capture
    id = transaction_id
    assert response = @gateway.capture(amount, response.authorization, {:id => id})
    assert_equal 'Approved', response.message
    assert_equal id, response.params['litleOnlineResponse']['captureResponse']['id']

    # 1B: credit
    id = transaction_id
    assert response = @gateway.credit(amount, response.authorization, {:id => id})
    assert_equal 'Approved', response.message
    assert_equal id, response.params['litleOnlineResponse']['creditResponse']['id']

    # 1C: void
    id = transaction_id
    assert response = @gateway.void(response.authorization, {:id => id})
    assert_equal 'Approved', response.message
    assert_equal id, response.params['litleOnlineResponse']['voidResponse']['id']
  end

  def authorize_avs_assertions(credit_card, options, assertions={})
    assert response = @gateway.authorize(0, credit_card, options)
    assert_equal assertions.key?(:success) ? assertions[:success] : true, response.success?
    assert_equal assertions[:message] || 'Approved', response.message
    assert_equal assertions[:avs], response.avs_result["code"], caller.inspect
    assert_equal assertions[:cvv], response.cvv_result["code"], caller.inspect if assertions[:cvv]
    assert_equal options[:order_id], response.params['litleOnlineResponse']['authorizationResponse']['id']
  end

  def sale_assertions(amount, card, options, assertions)
    # 1: sale
    assert response = @gateway.purchase(amount, card, options)
    assert_success response
    assert_equal 'Approved', response.message
    assert_equal assertions[:avs], response.avs_result["code"]
    assert_equal assertions[:cvv], response.cvv_result["code"] if assertions[:cvv]
    assert_equal options[:order_id], response.params['litleOnlineResponse']['saleResponse']['id']

    # 1B: credit
    id = transaction_id
    assert response = @gateway.credit(amount, response.authorization, {:id => id})
    assert_equal 'Approved', response.message
    assert_equal id, response.params['litleOnlineResponse']['creditResponse']['id']

    # 1C: void
    id = transaction_id
    assert response = @gateway.void(response.authorization, {:id => id})
    assert_equal 'Approved', response.message
    assert_equal id, response.params['litleOnlineResponse']['voidResponse']['id']
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
end
