require 'test_helper'

class RemoteLitleTest < Test::Unit::TestCase
  def setup
    Base.gateway_mode = :test
    @gateway = LitleGateway.new(fixtures(:litle))
    @credit_card_hash = {
      :first_name => 'John',
      :last_name  => 'Smith',
      :month      => '01',
      :year       => '2012',
      :brand      => 'visa',
      :number     => '4457010000000009',
      :verification_value => '349'
    }

    @options = {
      :order_id=>'1',
      :billing_address=>{
        :name      => 'John Smith',
        :company   => 'testCompany',
        :address1  => '1 Main St.',
        :city      => 'Burlington',
        :state     => 'MA',
        :country   => 'USA',
        :zip       => '01803-3747',
        :phone     => '1234567890'
      }
    }
    @credit_card1 = CreditCard.new(@credit_card_hash)

    @credit_card2 = CreditCard.new(
      :first_name         => "Joe",
      :last_name          => "Green",
      :month              => "06",
      :year               => "2012",
      :brand              => "visa",
      :number             => "4457010100000008",
      :verification_value => "992"
    )
  end

  def test_successful_authorization
    assert response = @gateway.authorize(10010, @credit_card1, @options)
    assert_success response
    assert_equal 'Approved', response.message
  end
  
  def test_unsuccessful_authorization
    assert response = @gateway.authorize(60060, @credit_card2,
      {
        :order_id=>'6',
        :billing_address=>{
          :name      => 'Joe Green',
          :address1  => '6 Main St.',
          :city      => 'Derry',
          :state     => 'NH',
          :zip       => '03038',
          :country   => 'US'
        },
      }
    )
    assert_failure response
    assert_equal 'Insufficient Funds', response.message
  end
  
  def test_successful_purchase
    #Litle sale
    assert response = @gateway.purchase(10010, @credit_card1, @options)
    assert_success response
    assert_equal 'Approved', response.message
  end
  
  def test_unsuccessful_purchase
    assert response = @gateway.purchase(60060, @credit_card2, {
        :order_id=>'6',
        :billing_address=>{
          :name      => 'Joe Green',
          :address1  => '6 Main St.',
          :city      => 'Derry',
          :state     => 'NH',
          :zip       => '03038',
          :country   => 'US'
        },
      }
    )
    assert_failure response
    assert_equal 'Insufficient Funds', response.message
  end

  def test_authorization_capture_credit_void
    #Auth
    assert auth_response = @gateway.authorize(10010, @credit_card1, @options)

    assert_success auth_response
    assert_equal 'Approved', auth_response.message
    
    #Capture the auth
    assert capture_response = @gateway.capture(10010, auth_response.authorization)
    assert_success capture_response
    assert_equal 'Approved', capture_response.message
    
    #Credit against the Capture
    capture_litle_txn_id = capture_response.params['litleOnlineResponse']['captureResponse']['litleTxnId']
    assert credit_response = @gateway.credit(10010, capture_litle_txn_id)
    assert_success credit_response
    assert_equal 'Approved', credit_response.message
    
    #Void that credit
    credit_litle_txn_id = credit_response.params['litleOnlineResponse']['creditResponse']['litleTxnId']
    assert void_response = @gateway.void(credit_litle_txn_id)
    assert_success void_response
    assert_equal 'Approved', void_response.message
  end
  
  def test_capture_unsuccessful 
    assert capture_response = @gateway.capture(10010, 123456789012345360)
    assert_failure capture_response
    assert_equal 'No transaction found with specified litleTxnId', capture_response.message
  end

  def test_credit_unsuccessful 
    assert credit_response = @gateway.credit(10010, 123456789012345360)
    assert_failure credit_response
    assert_equal 'No transaction found with specified litleTxnId', credit_response.message
  end
  
  def test_void_unsuccessful 
    assert void_response = @gateway.void(123456789012345360)
    assert_failure void_response
    assert_equal 'No transaction found with specified litleTxnId', void_response.message
  end
  
  def test_store_successful
    credit_card = CreditCard.new(@credit_card_hash.merge(:number => '4457119922390123'))
    assert store_response = @gateway.store(credit_card, :order_id => '50')

    assert_success store_response
    assert_equal 'Account number was successfully registered', store_response.message
    assert_equal '445711', store_response.params['litleOnlineResponse']['registerTokenResponse']['bin']
    assert_equal 'VI', store_response.params['litleOnlineResponse']['registerTokenResponse']['type'] #type is on Object in 1.8.7 - later versions can use .registerTokenResponse.type
    assert_equal '801', store_response.params['litleOnlineResponse']['registerTokenResponse']['response']
    assert_equal '1111222233330123', store_response.params['litleOnlineResponse']['registerTokenResponse']['litleToken']
  end
  
  def test_store_unsuccessful
    credit_card = CreditCard.new(@credit_card_hash.merge(:number => '4457119999999999'))
    assert store_response = @gateway.store(credit_card, :order_id => '51')

    assert_failure store_response
    assert_equal 'Credit card number was invalid', store_response.message
    assert_equal '820', store_response.params['litleOnlineResponse']['registerTokenResponse']['response']
  end

end
