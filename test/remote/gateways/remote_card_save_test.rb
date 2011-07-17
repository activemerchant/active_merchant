require 'test_helper'

class RemoteCardSaveTest < Test::Unit::TestCase  

  def setup
    @gateway = CardSaveGateway.new(fixtures(:card_save))
    
    @amount = 100
    @credit_card = credit_card('4976000000003436', :verification_value => '452')
    @declined_card = credit_card('4221690000004963', :verification_value => '125')
    @addresses = {'4976000000003436' => { :name => 'John Watson', :address1 => '32 Edward Street', :city => 'Camborne,', :state => 'Cornwall', :country => 'GB', :zip => 'TR14 8PA' },
                  '4221690000004963' => { :name => 'Ian Lee', :address1 => '274 Lymington Avenue', :city => 'London', :state => 'London', :country => 'GB', :zip => 'N22 6JN' }}
    
    @options = { 
      :order_id => '1',
      :billing_address => @addresses[@credit_card.number],
      :description => 'Store Purchase'
    }
  end
  
  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert response.message =~ /AuthCode: ([0-9]+)/
  end

  def test_unsuccessful_purchase
    @options.merge!(:billing_address => @addresses[@declined_card.number])
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Card declined', response.message
  end

  def test_authorize_and_capture
    amount = @amount+10
    assert auth = @gateway.authorize(amount, @credit_card, @options)
    assert_success auth
    assert auth.message =~ /AuthCode: ([0-9]+)/
    assert auth.authorization
    assert capture = @gateway.capture(amount, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    assert response = @gateway.capture(@amount, '')
    assert_failure response
    assert_equal 'Input variable errors', response.message
  end

  def test_invalid_login
    gateway = CardSaveGateway.new(
    :login => '',
    :password => ''
    )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Input variable errors', response.message
  end
end
