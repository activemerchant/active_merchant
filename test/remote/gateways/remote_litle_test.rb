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

  def test_authorization_capture_refund_void
    assert auth = @gateway.authorize(10010, @credit_card1, @options)
    assert_success auth
    assert_equal 'Approved', auth.message

    assert capture = @gateway.capture(nil, auth.authorization)
    assert_success capture
    assert_equal 'Approved', capture.message

    assert refund = @gateway.refund(nil, capture.authorization)
    assert_success refund
    assert_equal 'Approved', refund.message

    assert void = @gateway.void(refund.authorization)
    assert_success void
    assert_equal 'Approved', void.message
  end

  def test_partial_capture
    assert auth = @gateway.authorize(10010, @credit_card1, @options)
    assert_success auth
    assert_equal 'Approved', auth.message

    assert capture = @gateway.capture(5005, auth.authorization)
    assert_success capture
    assert_equal 'Approved', capture.message
  end

  def test_full_amount_capture
    assert auth = @gateway.authorize(10010, @credit_card1, @options)
    assert_success auth
    assert_equal 'Approved', auth.message

    assert capture = @gateway.capture(10010, auth.authorization)
    assert_success capture
    assert_equal 'Approved', capture.message
  end

  def test_nil_amount_capture
    assert auth = @gateway.authorize(10010, @credit_card1, @options)
    assert_success auth
    assert_equal 'Approved', auth.message

    assert capture = @gateway.capture(nil, auth.authorization)
    assert_success capture
    assert_equal 'Approved', capture.message
  end

  def test_capture_unsuccessful
    assert capture_response = @gateway.capture(10010, 123456789012345360)
    assert_failure capture_response
    assert_equal 'No transaction found with specified litleTxnId', capture_response.message
  end

  def test_refund_unsuccessful
    assert credit_response = @gateway.refund(10010, 123456789012345360)
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

  def test_store_and_purchase_with_token_successful
    credit_card = CreditCard.new(@credit_card_hash.merge(:number => '4100280190123000'))
    assert store_response = @gateway.store(credit_card, :order_id => '50')

    assert_success store_response

    token = store_response.authorization
    assert_equal store_response.params['litleOnlineResponse']['registerTokenResponse']['litleToken'], token

    options = {
        :order_id => '12345',
        :token    => {
            :month => credit_card.month,
            :year  => credit_card.year
        }
    }

    assert response = @gateway.purchase(10010, token, options)
    assert_success response
    assert_equal 'Approved', response.message
  end

end
