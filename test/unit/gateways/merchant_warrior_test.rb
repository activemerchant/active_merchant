require 'test_helper'


class MerchantWarriorTest < Test::Unit::TestCase
  def setup
    @gateway = MerchantWarriorGateway.new(
                 :merchant_uuid => '4b6bb68c75487',
                 :api_key => 'jwcd0uz1',
                 :api_passphrase => 'k9hflvig'
               )

    @credit_card = credit_card


    @success_amount = '100.00'
    @transaction_id = '30-98a79008-dae8-11df-9322-0022198101cd'

    @failure_amount = '100.33'

    @options = {
      :address => {
        :name => 'Longbob Longsen',
        :country => 'AU',
        :state => 'Queensland',
        :city => 'Brisbane',
        :address1 => '123 test st',
        :zip => '4000'
      },
      :transaction_product => 'TestProduct',
      :credit_amount => @success_amount
    }

  end

  def test_successful_purchase
		@gateway.expects(:ssl_post).returns(successful_purchase_response)
    assert response = @gateway.purchase(@success_amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_equal 'Transaction approved', response.params["response_message"]
    assert_success response

    assert response.test?
  end

  def test_unsuccessful_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    assert response = @gateway.purchase(@failure_amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_equal 'Card has expired', response.params["response_message"]
    assert_failure response
    assert response.test?
  end

  def test_successful_credit
    @gateway.expects(:ssl_post).returns(successful_credit_response)

    assert response = @gateway.credit(@success_amount, @transaction_id,
                                      @options)
    assert_instance_of Response, response
    assert_equal 'Transaction approved', response.params["response_message"]
    assert_success response

    assert response.test?
  end

  def test_unsuccessful_credit
    @gateway.expects(:ssl_post).returns(failed_credit_response)

    assert response = @gateway.credit(@success_amount, @transaction_id,
                                      @options)
    assert_instance_of Response, response
    assert_equal 'MW -016:transactionID has already been reversed', response.params["response_message"]
    assert_failure response
    assert response.test?
  end

  
  private

  # Place raw successful response from gateway here
  def successful_purchase_response
    <<-XML
<?xml version="1.0" encoding="UTF-8"?>
<mwResponse>
  <responseCode>0</responseCode>
  <responseMessage>Transaction approved</responseMessage>
  <transactionID>30-98a79008-dae8-11df-9322-0022198101cd</transactionID>
  <authCode>44639</authCode>
  <authMessage>Approved</authMessage>
  <authResponseCode>0</authResponseCode>
  <authSettledDate>2010-10-19</authSettledDate>
  <custom1></custom1>
  <custom2></custom2>
  <custom3></custom3>
  <customHash>c0aca5a0d9573322c79cc323d6cc8050</customHash>
</mwResponse>
    XML
  end

  # Place raw failed response from gateway here
  def failed_purchase_response
    <<-XML
<?xml version="1.0" encoding="UTF-8"?>
<mwResponse>
  <responseCode>4</responseCode>
  <responseMessage>Card has expired</responseMessage>
  <transactionID>30-69433444-af1-11df-9322-0022198101cd</transactionID>
  <authCode>44657</authCode>
  <authMessage>Expired+Card</authMessage>
  <authResponseCode>4</authResponseCode>
  <authSettledDate>2010-10-19</authSettledDate>
  <custom1></custom1>
  <custom2></custom2>
  <custom3></custom3>
  <customHash>c0aca5a0d9573322c79cc323d6cc8050</customHash>
</mwResponse>
    XML
  end

  def successful_credit_response
    <<-XML
<?xml version="1.0" encoding="UTF-8"?>
<mwResponse>
  <responseCode>0</responseCode>
  <responseMessage>Transaction approved</responseMessage>
  <transactionID>30-d4d19f4-db17-11df-9322-0022198101cd</transactionID>
  <authCode>44751</authCode>
  <authMessage>Approved</authMessage>
  <authResponseCode>0</authResponseCode>
  <authSettledDate>2010-10-19</authSettledDate>
</mwResponse>
    XML
  end

  def failed_credit_response
    <<-XML
<?xml version="1.0" encoding="UTF-8"?>
  <mwResponse>
  <responseCode>-2</responseCode>
  <responseMessage>MW -016:transactionID has already been reversed</responseMessage>
</mwResponse>
    XML
  end
end