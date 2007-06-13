require File.dirname(__FILE__) + '/../../test_helper'

class SecurePayTest < Test::Unit::TestCase
  include ActiveMerchant::Billing

  def setup
    @gateway = SecurePayGateway.new(
      :login => 'X',
      :password => 'Y'
    )

    @creditcard = CreditCard.new(
      :number => '4242424242424242',
      :month => 8,
      :year => 2006,
      :first_name => 'Longbob',
      :last_name => 'Longsen'
    )
  end

  def test_failed_purchase
    @gateway.stubs(:ssl_post).returns(failure_response)
    
    assert response = @gateway.purchase(100, @creditcard,
      :order_id => generate_order_id,
      :description => 'Store purchase',
      :billing_address => {
        :first_name => 'Cody',
        :last_name => 'Fauser',
        :address1 => '1234 Test St.',
        :city => 'Ottawa',
        :state => 'ON',
        :country => 'Canada',
        :zip => 'K2P7G2'
      }
    )
    assert !response.success?
    assert response.test?
    assert_equal 'This transaction has been declined', response.message
    assert_equal '3377475', response.authorization
  end
  
  def test_successful_purchase
    @gateway.stubs(:ssl_post).returns(successful_purchase_response)
    
    assert response = @gateway.purchase(100, @creditcard,
      :order_id => generate_order_id,
      :description => 'Store purchase'
    )
    
    assert response.success?
    assert response.test?
    assert_equal 'This transaction has been approved', response.message
    assert response.authorization
  end
  
  def test_undefine_unsupported_methods
    assert @gateway.respond_to?(:purchase)
    
    [ :authorize, :capture, :void, :credit ].each do |m|
      assert !@gateway.respond_to?(m)
    end
  end
  
  private
  
  def successful_purchase_response
    '1%%1%This transaction has been approved.%100721%X%3377575%f6af895031c07d88399ed9fdb48c8476%Store+purchase%0.01%%AUTH_CAPTURE%%Cody%Fauser%%100+Example+St.%Ottawa%ON%K2A5P7%Canada%%%%%%%%%%%%%%%%%%%'
  end

  def failure_response
    '2%%2%This transaction has been declined.%NOT APPROVED%U%3377475%55adbbaed13aa7e2526846d672fdb594%Store+purchase%1.00%%AUTH_CAPTURE%%Longbob%Longsen%%1234+Test+St.%Ottawa%ON%K1N5P8%Canada%%%%%%%%%%%%%%%%%%%'
  end
  
  def failed_capture_response
    '3%%6%The credit card number is invalid.%%%%%%0.01%%PRIOR_AUTH_CAPTURE%%%%%%%%%%%%%%%%%%%%%%%%%%%%'
  end
end
