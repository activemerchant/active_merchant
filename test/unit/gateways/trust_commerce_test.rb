require 'test_helper'

class TrustCommerceTest < Test::Unit::TestCase
  def setup
    @gateway = TrustCommerceGateway.new(
      :login => 'TestMerchant',
      :password => 'password',
      :vault_password => "test"
    )
    # Force SSL post
    @gateway.stubs(:tclink?).returns(false)

    @amount = 100
    @credit_card = credit_card('4111111111111111')
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    assert response = @gateway.purchase(@amount, @credit_card)
    assert_instance_of Response, response
    assert_success response
    assert_equal '025-0007423614', response.authorization
  end

  def test_unsuccessful_purchase
    @gateway.expects(:ssl_post).returns(unsuccessful_purchase_response)
    assert response = @gateway.purchase(@amount, @credit_card)
    assert_instance_of Response, response
    assert_failure response
  end

  def test_successful_recurring_with_credit_card
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    @gateway.expects(:add_creditcard)
    assert response = @gateway.recurring(@amount, @credit_card, :periodicity => :monthly)
    assert_instance_of Response, response
    assert_success response
  end

  def test_successful_recurring_with_billing_id
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    @gateway.expects(:add_billing_id)
    assert response = @gateway.recurring(@amount, "B1LL1D", :periodicity => :monthly)
    assert_instance_of Response, response
    assert_success response
  end
   
  def test_amount_style   
   assert_equal '1034', @gateway.send(:amount, 1034)
                                                  
   assert_raise(ArgumentError) do
     @gateway.send(:amount, '10.34')
   end
  end
  
  def test_avs_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    
    response = @gateway.purchase(@amount, @credit_card)
    assert_equal 'Y', response.avs_result['code']
  end
  
  def test_cvv_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    
    response = @gateway.purchase(@amount, @credit_card)
    assert_equal 'P', response.cvv_result['code']
  end
  
  def test_supported_countries
    assert_equal ['US'], TrustCommerceGateway.supported_countries
  end

  def test_supported_card_types
    assert_equal [:visa, :master, :discover, :american_express, :diners_club, :jcb], TrustCommerceGateway.supported_cardtypes
  end
  
  def test_test_flag_should_be_set_when_using_test_login_in_production
    Base.gateway_mode = :production
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    assert response = @gateway.purchase(@amount, @credit_card)
    assert_success response
    assert response.test?
  ensure
    Base.gateway_mode = :test
  end

  def test_successful_transaction_query
    @gateway.expects(:ssl_post).returns(successful_transaction_query_response)
    assert response = @gateway.query_transaction(:vault_password => "asdfasdf")
    assert_instance_of QueryResponse, response
    assert_success response
    assert response.test?
    assert_equal response.entries.count, 1
  end
  
  private
  
  def successful_purchase_response
    <<-RESPONSE
transid=025-0007423614
status=approved
avs=Y
cvv=P
    RESPONSE
  end
  
  def unsuccessful_purchase_response
    <<-RESPONSE
transid=025-0007423827
declinetype=cvv
status=decline
cvv=N
    RESPONSE
  end

  def successful_transaction_query_response
    <<-RESPONSE
cc,media_name,exp,trans_date,transid,ref_transid,amount,auth_amount,bank_amount,credit_amount,chargeback_amount,action_name,status_name,name,address1,address2,city,state,zip,phone,email,shiptosame,shipto_name,shipto_address1,shipto_address2,shipto_city,shipto_state,shipto_zip,expired,reauth,chain,chain_head,ticket,batchnum,authcode,billingid,custid,fail_name,avs,operator,country_code,tax,purchaseordernum,batchid,closed,entry_mode,responsecode,telecheck_traceid
4242,VISA-D,0812,11-17-2011 12:26:25,023-0096483123,,1000,1000,1000,,,sale,approved,Bob Bobsen,,,,,,,,,,,,,,,f,,251974156,t,,,123456,,682800,,,,,0,,,,Manual Entry,,
    RESPONSE
  end
end
