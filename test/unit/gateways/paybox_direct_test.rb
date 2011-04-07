require 'test_helper'

class PayboxDirectTest < Test::Unit::TestCase
  def setup
    @gateway = PayboxDirectGateway.new(
                 :login => 'l',
                 :password => 'p'
               )

    @credit_card = credit_card('1111222233334444',
                      :type => 'visa'
                   )
    @amount = 100
    
    @options = { 
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end
  
  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)

    assert_instance_of Response, response
    assert_success response
    
    # Replace with authorization number from the successful response
    assert_equal response.params['numappel'].to_s + response.params['numtrans'], response.authorization
    assert_equal 'XXXXXX', response.params['autorisation']
    assert response.test?
  end

  def test_deprecated_credit
    @gateway.expects(:ssl_post).with(anything, regexp_matches(/NUMAPPEL=transid/), anything).returns("")
    @gateway.expects(:parse).returns({})
    @gateway.credit(@amount, "transid", @options)
  end
  
  def test_refund
    @gateway.expects(:ssl_post).with(anything, regexp_matches(/NUMAPPEL=transid/), anything).returns("")
    @gateway.expects(:parse).returns({})
    @gateway.refund(@amount, "transid", @options)
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_post).returns(failed_purchase_response)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_version
    @gateway.expects(:ssl_post).with(anything, regexp_matches(/VERSION=00103/)).returns(successful_purchase_response)
    @gateway.purchase(@amount, @credit_card, @options)
  end
  
  private
  
  # Place raw successful response from gateway here
  def successful_purchase_response
    'NUMTRANS=0720248861&NUMAPPEL=0713790302&NUMQUESTION=0000790217&SITE=1999888&RANG=99&AUTORISATION=XXXXXX&CODEREPONSE=00000&COMMENTAIRE=Demande trait?e avec succ?s'
  end
  
  # Place raw failed response from gateway here
  def failed_purchase_response
    'NUMTRANS=0000000000&NUMAPPEL=0000000000&NUMQUESTION=0000000000&SITE=1999888&RANG=99&AUTORISATION=&CODEREPONSE=00014'
  end
end
