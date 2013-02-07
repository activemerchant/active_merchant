require 'test_helper'


class MerchantWarriorTest < Test::Unit::TestCase
  def setup
    @gateway = MerchantWarriorGateway.new(
                 :merchant_uuid => '4e922de8c2a4c',
                 :api_key => 'g6jrxa9o',
                 :api_passphrase => 'vp4ujoem'
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
      :transaction_product => 'TestProduct'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.purchase(@success_amount, @credit_card, @options)
    assert_success response
    assert_equal 'Transaction approved', response.message
    assert response.test?
    assert_equal "30-98a79008-dae8-11df-9322-0022198101cd", response.authorization
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    assert response = @gateway.purchase(@failure_amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Card has expired', response.message
    assert response.test?
    assert_equal "30-69433444-af1-11df-9322-0022198101cd", response.authorization
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)

    assert response = @gateway.refund(@success_amount, @transaction_id)
    assert_success response
    assert_equal 'Transaction approved', response.message
    assert response.test?
    assert_equal "30-d4d19f4-db17-11df-9322-0022198101cd", response.authorization
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)

    assert response = @gateway.refund(@success_amount, @transaction_id)
    assert_failure response
    assert_equal 'MW -016:transactionID has already been reversed', response.message
    assert response.test?
    assert_nil response.authorization
  end

  def test_successful_store
    @gateway.expects(:ssl_post).returns(successful_store_response)

    assert store = @gateway.store(@credit_card, @options)
    assert_success store
    assert_equal "Operation successful", store.message
    assert_match "KOCI10023982", store.authorization
  end

  private

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

  def successful_refund_response
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

  def failed_refund_response
    <<-XML
<?xml version="1.0" encoding="UTF-8"?>
  <mwResponse>
  <responseCode>-2</responseCode>
  <responseMessage>MW -016:transactionID has already been reversed</responseMessage>
</mwResponse>
    XML
  end

  def successful_store_response
    <<-XML
<?xml version="1.0" encoding="UTF-8"?>
<mwResponse>
  <responseCode>0</responseCode>
  <responseMessage>Operation successful</responseMessage>
  <cardID>KOCI10023982</cardID>
  <cardKey>s5KQIxsZuiyvs3Sc</cardKey>
  <ivrCardID>10023982</ivrCardID>
</mwResponse>
    XML
  end
end
