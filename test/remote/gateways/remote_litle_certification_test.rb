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
      :year => '2012',
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
                                 :year => '2012', :brand => 'master', 
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
      :year => '2012',
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
      :year => '2012',
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
                                 :year => '2012', :brand => 'visa', 
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
    assert_equal 'Insufficient Funds', response.message
    assert_equal "I", response.avs_result["code"]
    assert_equal "P", response.cvv_result["code"]

    # 6. sale
    assert response = @gateway.purchase(60060, credit_card, options)
    assert !response.success?
    assert_equal 'Insufficient Funds', response.message
    assert_equal "I", response.avs_result["code"]
    assert_equal "P", response.cvv_result["code"]

    # 6A. void
    assert response = @gateway.void(response.authorization)
    assert_equal 'No transaction found with specified litleTxnId', response.message
  end

  def test7
    credit_card = CreditCard.new(:number => '5112010100000002', :month => '07', 
                                 :year => '2012', :brand => 'master', 
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
    assert_equal 'Invalid Account Number', response.message
    assert_equal "I", response.avs_result["code"]
    assert_equal "N", response.cvv_result["code"]

    # 7: authorize avs
    authorize_avs_assertions(credit_card, options, :avs => "I", :cvv => "N", :message => "Invalid Account Number", :success => false)

    # 7. sale
    assert response = @gateway.purchase(60060, credit_card, options)
    assert !response.success?
    assert_equal 'Invalid Account Number', response.message
    assert_equal "I", response.avs_result["code"]
    assert_equal "N", response.cvv_result["code"]
  end

  def test8
    credit_card = CreditCard.new(:number => '6011010100000002', :month => '08', 
                                 :year => '2012', :brand => 'discover', 
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
    assert_equal 'Call Discover', response.message
    assert_equal "I", response.avs_result["code"]
    assert_equal "P", response.cvv_result["code"]

    # 8: authorize avs
    authorize_avs_assertions(credit_card, options, :avs => "I", :cvv => "P", :message => "Call Discover", :success => false)

    # 8: sale
    assert response = @gateway.purchase(80080, credit_card, options)
    assert !response.success?
    assert_equal 'Call Discover', response.message
    assert_equal "I", response.avs_result["code"]
    assert_equal "P", response.cvv_result["code"]
  end

  def test9
    credit_card = CreditCard.new(:number => '375001010000003', :month => '09', 
                                 :year => '2012', :brand => 'american_express', 
                                 :verification_value => '0421')

    options = {
      :order_id => '8',
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
    assert_equal 'Pick Up Card', response.message
    assert_equal "I", response.avs_result["code"]

    # 9: authorize avs
    authorize_avs_assertions(credit_card, options, :avs => "I", :message => "Pick Up Card", :success => false)

    # 9: sale
    assert response = @gateway.purchase(90090, credit_card, options)
    assert !response.success?
    assert_equal 'Pick Up Card', response.message
    assert_equal "I", response.avs_result["code"]
  end

  private
  def auth_assertions(amount, card, options, assertions)
    # 1: authorize
    assert response = @gateway.authorize(amount, card, options)
    assert_success response
    assert_equal 'Approved', response.message
    assert_equal assertions[:avs], response.avs_result["code"]
    assert_equal assertions[:cvv], response.cvv_result["code"] if assertions[:cvv]

    # 1A: capture
    assert response = @gateway.capture(amount, response.authorization)
    assert_equal 'Approved', response.message

    # 1B: credit
    assert response = @gateway.credit(amount, response.authorization)
    assert_equal 'Approved', response.message

    # 1C: void
    assert response = @gateway.void(response.authorization)
    assert_equal 'Approved', response.message
  end

  def authorize_avs_assertions(credit_card, options, assertions={})
    assert response = @gateway.authorize(0, credit_card, options)
    assert_equal assertions.key?(:success) ? assertions[:success] : true, response.success?
    assert_equal assertions[:message] || 'Approved', response.message
    assert_equal assertions[:avs], response.avs_result["code"], caller.inspect
    assert_equal assertions[:cvv], response.cvv_result["code"], caller.inspect if assertions[:cvv]
  end

  def sale_assertions(amount, card, options, assertions)
    # 1: sale
    assert response = @gateway.purchase(amount, card, options)
    assert_success response
    assert_equal 'Approved', response.message
    assert_equal assertions[:avs], response.avs_result["code"]
    assert_equal assertions[:cvv], response.cvv_result["code"] if assertions[:cvv]

    # 1B: credit
    assert response = @gateway.credit(amount, response.authorization)
    assert_equal 'Approved', response.message

    # 1C: void
    assert response = @gateway.void(response.authorization)
    assert_equal 'Approved', response.message
  end

end
