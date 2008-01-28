require File.dirname(__FILE__) + '/../../test_helper'

class DataCashTest < Test::Unit::TestCase
  # 100 Cents
  AMOUNT = 100

  def setup
    @gateway = DataCashGateway.new(
      :login => 'LOGIN',
      :password => 'PASSWORD'
    )

    @credit_card = credit_card('4242424242424242')
    
    @address = { 
      :name     => 'Mark McBride',
      :address1 => 'Flat 12/3',
      :address2 => '45 Main Road',
      :city     => 'London',
      :state    => 'None',
      :country  => 'GBR',
      :zip      => 'A987AA',
      :phone    => '(555)555-5555'
    }
    
    @options = {
      :order_id => generate_unique_id,
      :billing_address => @address
    }
  end
  
  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    assert response.test?
    assert_equal 'The transaction was successful', response.message
    assert_equal '4400200050664928;123456789', response.authorization
  end
  
  def test_unsuccessful_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)
    
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_failure response
    assert response.test?
    assert_equal 'Invalid reference number', response.message
  end
  
  def test_error_
    @gateway.expects(:ssl_post).returns(failed_purchase_response)
    
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_failure response
    assert response.test?
    assert_equal 'Invalid reference number', response.message
  end
  
  def test_supported_countries
    assert_equal ['GB'], DataCashGateway.supported_countries
  end
  
  def test_supported_card_types
    assert_equal [ :visa, :master, :american_express, :discover, :diners_club, :jcb, :maestro, :switch, :solo, :laser ], DataCashGateway.supported_cardtypes
  end
  
  private
  def failed_purchase_response
    <<-XML
<Response>
  <status>22</status>
  <time>1196414665</time>
  <mode>TEST</mode>
  <country>United Kingdom</country>
  <merchantreference>2d24cc91284c1ed5c65d8821f1e752c7</merchantreference>
  <issuer>Clydesdale Bank PLC</issuer>
  <reason>Invalid reference number</reason>
  <card_scheme>Solo</card_scheme>
  <datacash_reference>4400200050664928</datacash_reference>
</Response>
    XML
  end
  
  def successful_purchase_response
    <<-XML
<Response>
  <status>1</status>
  <time>1196414665</time>
  <mode>TEST</mode>
  <country>United Kingdom</country>
  <merchantreference>2d24cc91284c1ed5c65d8821f1e752c7</merchantreference>
  <issuer>Clydesdale Bank PLC</issuer>
  <reason>The transaction was successful</reason>
  <card_scheme>Visa</card_scheme>
  <datacash_reference>4400200050664928</datacash_reference>
  <authcode>123456789</authcode>
</Response>
    XML
  end
end