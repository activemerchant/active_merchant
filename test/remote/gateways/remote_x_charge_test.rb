require 'test_helper'

class RemoteXChargeTest < Test::Unit::TestCase
  
  def setup
    @gateway = XChargeGateway.new(fixtures(:x_charge))
    
    @amount = 100
    @decline_amount = 1301
    @credit_card = credit_card('4000100011112224')
    
    @options = { 
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end
  
  def test_succesful_authorization
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Approval', response.message
  end
  
  def test_failed_authorization
    assert response = @gateway.authorize(@decline_amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Decline', response.message
  end
  
  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Approval', response.message
  end

  def test_failed_purchase
    assert response = @gateway.purchase(@decline_amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Decline', response.message
  end
  
  def test_authorize_and_capture
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'Approval', auth.message
    assert auth.authorization
    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
  end
  
  def test_failed_capture    
    assert response = @gateway.capture(@amount, '123')
    assert_failure response
    assert_match /Error/, response.message
  end
  
  def test_successful_void
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    assert_equal 'Approval', purchase.message
    
    assert response = @gateway.void(purchase.authorization)
    assert_success response
    assert_equal 'Approval', response.message
  end
  
  def test_failed_void   
    assert response = @gateway.void('123')
    assert_failure response
    assert_match /Error/, response.message
  end
  
  def test_successful_return
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    assert_equal 'Approval', purchase.message

    assert response = @gateway.return(@amount, purchase.authorization)
    assert_success response
    assert_equal 'Approval', response.message
  end

  def test_failed_return
    assert response = @gateway.return(@amount, '123')
    assert_failure response
    assert_match /Error/, response.message
  end
  
  def test_successful_alias_create
    assert response = @gateway.alias_create(@credit_card, @options)
    assert_success response
    assert_equal 'Alias Success: Created', response.message
  end
  
  def test_failed_alias_create
    assert response = @gateway.alias_create(credit_card(''), @options)
    assert_failure response
    assert_match /Error/, response.message
  end
  
  def test_successful_alias_update
    assert alias_response = @gateway.alias_create(@credit_card, @options)
    assert_success alias_response
    assert_equal 'Alias Success: Created', alias_response.message
        
    assert response = @gateway.alias_update(alias_response.params["Alias"], @credit_card)
    assert_success response
    assert_equal 'Alias Success: Updated', response.message
  end
  
  def test_failed_alias_update
    assert response = @gateway.alias_update("123", @credit_card)
    assert_failure response
    assert_match /Error/, response.message
  end
  
  def test_successful_alias_lookup
    assert alias_response = @gateway.alias_create(@credit_card, @options)
    assert_success alias_response
    assert_equal 'Alias Success: Created', alias_response.message
        
    assert response = @gateway.alias_lookup(alias_response.authorization)
    assert_success response
    assert_equal 'Alias Success: Looked Up', response.message
  end
  
  def test_failed_alias_lookup
    assert response = @gateway.alias_lookup("123")
    assert_failure response
    assert_match /Error/, response.message
  end
  
  def test_successful_alias_delete
    assert alias_response = @gateway.alias_create(@credit_card, @options)
    assert_success alias_response
    assert_equal 'Alias Success: Created', alias_response.message
        
    assert response = @gateway.alias_delete(alias_response.authorization)
    assert_success response
    assert_equal 'Alias Success: Deleted', response.message
  end
  
  def test_failed_alias_delete
    assert response = @gateway.alias_delete("123")
    assert_failure response
    assert_match /Error/, response.message
  end
  
  def test_successful_purchase_with_alias
    assert alias_response = @gateway.alias_create(@credit_card, @options)
    assert_success alias_response
    assert_equal 'Alias Success: Created', alias_response.message
    
    assert response = @gateway.purchase(@amount, alias_response.authorization, @options)
    assert_success response
    assert_equal 'Approval', response.message
  end
  
  def test_failed_purchase_with_alias
    assert response = @gateway.purchase(@amount, "123", @options)
    assert_failure response
    assert_match /Error/, response.message
  end
  
  def test_successful_purchase_creating_alias
    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(:CreateAlias => true))
    assert_success response
    assert_equal 'Approval', response.message
  end
  
  def test_invalid_login
    gateway = XChargeGateway.new(
                :XWebID => 'login',
                :AuthKey => 'password',
                :TerminalID => "12345",
                :Industry => "ECOMMERCE"
              )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match /Error/, response.message
  end
end