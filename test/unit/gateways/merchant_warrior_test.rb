require 'test_helper'

class MerchantWarriorTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = MerchantWarriorGateway.new(
      merchant_uuid: '4e922de8c2a4c',
      api_key: 'g6jrxa9o',
      api_passphrase: 'vp4ujoem'
    )

    @credit_card = credit_card
    @success_amount = 10000
    @transaction_id = '30-98a79008-dae8-11df-9322-0022198101cd'
    @failure_amount = 10033

    @options = {
      address: address,
      transaction_product: 'TestProduct'
    }
    @three_ds_secure = {
      version: '2.2.0',
      cavv: '3q2+78r+ur7erb7vyv66vv\/\/\/\/8=',
      eci: '05',
      xid: 'ODUzNTYzOTcwODU5NzY3Qw==',
      enrolled: 'true',
      authentication_response_status: 'Y'
    }
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    assert response = @gateway.authorize(@success_amount, @credit_card, @options)
    assert_success response
    assert_equal 'Transaction approved', response.message
    assert response.test?
    assert_equal '1336-20be3569-b600-11e6-b9c3-005056b209e0', response.authorization
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(nil)

    assert response = @gateway.authorize(@success_amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Invalid gateway response', response.message
    assert response.test?
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.purchase(@success_amount, @credit_card, @options)
    assert_success response
    assert_equal 'Transaction approved', response.message
    assert response.test?
    assert_equal '30-98a79008-dae8-11df-9322-0022198101cd', response.authorization
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    assert response = @gateway.purchase(@failure_amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Card has expired', response.message
    assert response.test?
    assert_equal '30-69433444-af1-11df-9322-0022198101cd', response.authorization
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)

    assert response = @gateway.refund(@success_amount, @transaction_id, @options)
    assert_success response
    assert_equal 'Transaction approved', response.message
    assert response.test?
    assert_equal '30-d4d19f4-db17-11df-9322-0022198101cd', response.authorization
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)

    assert response = @gateway.refund(@success_amount, @transaction_id)
    assert_failure response
    assert_equal 'MW -016:transactionID has already been reversed', response.message
    assert response.test?
    assert_nil response.authorization
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_refund_response)

    assert response = @gateway.void(@transaction_id, amount: @success_amount)
    assert_success response
    assert_equal 'Transaction approved', response.message
    assert response.test?
    assert_equal '30-d4d19f4-db17-11df-9322-0022198101cd', response.authorization
  end

  def test_failed_void
    @gateway.expects(:ssl_post).returns(failed_refund_response)

    assert response = @gateway.void(@transaction_id, amount: @success_amount)
    assert_failure response
    assert_equal 'MW -016:transactionID has already been reversed', response.message
    assert response.test?
    assert_nil response.authorization
  end

  def test_successful_store
    @credit_card.month = '2'
    @credit_card.year = '2005'

    store = stub_comms do
      @gateway.store(@credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/cardExpiryMonth=02\b/, data)
      assert_match(/cardExpiryYear=05\b/, data)
    end.respond_with(successful_store_response)

    assert_success store
    assert_equal 'Operation successful', store.message
    assert_match 'KOCI10023982', store.authorization
  end

  def test_scrub_name
    @credit_card.first_name = "Chars; Merchant-Warrior Don't Like"
    @credit_card.last_name = '& More. # Here'
    @options[:address][:name] = 'Ren & Stimpy'

    stub_comms do
      @gateway.purchase(@success_amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/customerName=Ren\+\+Stimpy/, data)
      assert_match(/paymentCardName=Chars\+Merchant-Warrior\+Dont\+Like\+\+More\.\+\+Here/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_address
    @options[:address] = {
      name: 'Bat Man',
      address1: '123 Main',
      city: 'Brooklyn',
      state: 'NY',
      country: 'US',
      zip: '11111',
      phone: '555-1212',
      email: 'user@aol.com',
      ip: '1.2.3.4'
    }

    stub_comms do
      @gateway.purchase(@success_amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/customerName=Bat\+Man/, data)
      assert_match(/customerCountry=US/, data)
      assert_match(/customerState=NY/, data)
      assert_match(/customerCity=Brooklyn/, data)
      assert_match(/customerAddress=123\+Main/, data)
      assert_match(/customerPostCode=11111/, data)
      assert_match(/customerIP=1.2.3.4/, data)
      assert_match(/customerPhone=555-1212/, data)
      assert_match(/customerEmail=user%40aol.com/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_address_without_state
    @options[:address] = {
      name: 'Bat Man',
      state: nil
    }

    stub_comms do
      @gateway.purchase(@success_amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/customerState=N%2FA/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_orderid_truncated
    stub_comms do
      @gateway.purchase(@success_amount, @credit_card, order_id: 'ThisIsQuiteALongDescriptionWithLotsOfChars')
    end.check_request do |_endpoint, data, _headers|
      assert_match(/transactionProduct=ThisIsQuiteALongDescriptionWithLot&/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_authorize_recurring_flag_absent
    stub_comms do
      @gateway.authorize(@success_amount, @credit_card)
    end.check_request do |_endpoint, data, _headers|
      assert_not_match(/recurringFlag&/, data)
    end.respond_with(successful_authorize_response)
  end

  def test_authorize_recurring_flag_present
    recurring_flag = 1

    stub_comms do
      @gateway.authorize(@success_amount, @credit_card, recurring_flag: recurring_flag)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/recurringFlag=#{recurring_flag}&/, data)
    end.respond_with(successful_authorize_response)
  end

  def test_purchase_recurring_flag_absent
    stub_comms do
      @gateway.purchase(@success_amount, @credit_card)
    end.check_request do |_endpoint, data, _headers|
      assert_not_match(/recurringFlag&/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_purchase_recurring_flag_present
    recurring_flag = 1

    stub_comms do
      @gateway.purchase(@success_amount, @credit_card, recurring_flag: recurring_flag)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/recurringFlag=#{recurring_flag}&/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_authorize_with_soft_descriptor_absent
    stub_comms do
      @gateway.authorize(@success_amount, @credit_card)
    end.check_request do |_endpoint, data, _headers|
      assert_not_match(/descriptorName&/, data)
      assert_not_match(/descriptorCity&/, data)
      assert_not_match(/descriptorState&/, data)
    end.respond_with(successful_authorize_response)
  end

  def test_authorize_with_soft_descriptor_present
    stub_comms do
      @gateway.authorize(@success_amount, @credit_card, soft_descriptor_options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/descriptorName=FOO%2ATest&/, data)
      assert_match(/descriptorCity=Melbourne&/, data)
      assert_match(/descriptorState=VIC&/, data)
    end.respond_with(successful_authorize_response)
  end

  def test_purchase_with_soft_descriptor_absent
    stub_comms do
      @gateway.purchase(@success_amount, @credit_card)
    end.check_request do |_endpoint, data, _headers|
      assert_not_match(/descriptorName&/, data)
      assert_not_match(/descriptorCity&/, data)
      assert_not_match(/descriptorState&/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_purchase_with_soft_descriptor_present
    stub_comms do
      @gateway.purchase(@success_amount, @credit_card, soft_descriptor_options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/descriptorName=FOO%2ATest&/, data)
      assert_match(/descriptorCity=Melbourne&/, data)
      assert_match(/descriptorState=VIC&/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_capture_with_soft_descriptor_absent
    stub_comms do
      @gateway.capture(@success_amount, @credit_card)
    end.check_request do |_endpoint, data, _headers|
      assert_not_match(/descriptorName&/, data)
      assert_not_match(/descriptorCity&/, data)
      assert_not_match(/descriptorState&/, data)
    end.respond_with(successful_capture_response)
  end

  def test_capture_with_soft_descriptor_present
    stub_comms do
      @gateway.capture(@success_amount, @credit_card, soft_descriptor_options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/descriptorName=FOO%2ATest&/, data)
      assert_match(/descriptorCity=Melbourne&/, data)
      assert_match(/descriptorState=VIC&/, data)
    end.respond_with(successful_capture_response)
  end

  def test_refund_with_soft_descriptor_absent
    stub_comms do
      @gateway.refund(@success_amount, @credit_card)
    end.check_request do |_endpoint, data, _headers|
      assert_not_match(/descriptorName&/, data)
      assert_not_match(/descriptorCity&/, data)
      assert_not_match(/descriptorState&/, data)
    end.respond_with(successful_refund_response)
  end

  def test_refund_with_soft_descriptor_present
    stub_comms do
      @gateway.refund(@success_amount, @credit_card, soft_descriptor_options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/descriptorName=FOO%2ATest&/, data)
      assert_match(/descriptorCity=Melbourne&/, data)
      assert_match(/descriptorState=VIC&/, data)
    end.respond_with(successful_refund_response)
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  def test_three_ds_v2_object_construction
    post = {}
    @options[:three_d_secure] = @three_ds_secure

    @gateway.send(:add_three_ds, post, @options)
    ds_options = @options[:three_d_secure]

    assert_equal ds_options[:version], post[:threeDSV2Version]
    assert_equal ds_options[:cavv], post[:threeDSCavv]
    assert_equal ds_options[:eci], post[:threeDSEci]
    assert_equal ds_options[:xid], post[:threeDSXid]
    assert_equal ds_options[:authentication_response_status], post[:threeDSStatus]
  end

  def test_purchase_with_three_ds
    @options[:three_d_secure] = @three_ds_secure
    stub_comms(@gateway) do
      @gateway.purchase(@success_amount, @credit_card, @options)
    end.check_request(skip_response: true) do |_endpoint, data, _headers|
      params = URI.decode_www_form(data).to_h
      assert_equal '2.2.0', params['threeDSV2Version']
      assert_equal '3q2+78r+ur7erb7vyv66vv\/\/\/\/8=', params['threeDSCavv']
      assert_equal '05', params['threeDSEci']
      assert_equal 'ODUzNTYzOTcwODU5NzY3Qw==', params['threeDSXid']
      assert_equal 'Y', params['threeDSStatus']
    end
  end

  private

  def successful_purchase_response
    <<~XML
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
    <<~XML
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
    <<~XML
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
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
        <mwResponse>
        <responseCode>-2</responseCode>
        <responseMessage>MW -016:transactionID has already been reversed</responseMessage>
      </mwResponse>
    XML
  end

  def successful_store_response
    <<~XML
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

  def successful_authorize_response
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <mwResponse>
        <responseCode>0</responseCode>
        <responseMessage>Transaction approved</responseMessage>
        <transactionID>1336-20be3569-b600-11e6-b9c3-005056b209e0</transactionID>
        <transactionReferenceID>12345</transactionReferenceID>
        <authCode>731357421</authCode>
        <receiptNo>731357421</receiptNo>
        <authMessage>Honour with identification</authMessage>
        <authResponseCode>08</authResponseCode>
        <authSettledDate>2016-11-29</authSettledDate>
        <paymentCardNumber>512345XXXXXX2346</paymentCardNumber>
        <transactionAmount>1.00</transactionAmount>
        <cardType>mc</cardType>
        <cardExpiryMonth>05</cardExpiryMonth>
        <cardExpiryYear>21</cardExpiryYear>
        <custom1/>
        <custom2/>
        <custom3/>
        <customHash>65b172551b7d3a0706c0ce5330c98470</customHash>
      </mwResponse>
    XML
  end

  def successful_capture_response
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <mwResponse>
        <responseCode>0</responseCode>
        <responseMessage>Transaction approved</responseMessage>
        <transactionID>1336-fe4d3be6-b604-11e6-b9c3-005056b209e0</transactionID>
        <authCode>731357526</authCode>
        <receiptNo>731357526</receiptNo>
        <authMessage>Approved or completed successfully</authMessage>
        <authResponseCode>00</authResponseCode>
        <authSettledDate>2016-11-30</authSettledDate>
      </mwResponse>
    XML
  end

  def pre_scrubbed
    'transactionAmount=1.00&transactionCurrency=AUD&hash=adb50f6ff360f861e6f525e8daae76b5&transactionProduct=98fc25d40a47f3d24da460c0ca307c&customerName=Longbob+Longsen&customerCountry=AU&customerState=Queensland&customerCity=Brisbane&customerAddress=123+test+st&customerPostCode=4000&customerIP=&customerPhone=&customerEmail=&paymentCardNumber=5123456789012346&paymentCardName=Longbob+Longsen&paymentCardExpiry=0520&paymentCardCSC=123&merchantUUID=51f7da294af8f&apiKey=nooudtd0&method=processCard'
  end

  def post_scrubbed
    'transactionAmount=1.00&transactionCurrency=AUD&hash=adb50f6ff360f861e6f525e8daae76b5&transactionProduct=98fc25d40a47f3d24da460c0ca307c&customerName=Longbob+Longsen&customerCountry=AU&customerState=Queensland&customerCity=Brisbane&customerAddress=123+test+st&customerPostCode=4000&customerIP=&customerPhone=&customerEmail=&paymentCardNumber=[FILTERED]&paymentCardName=Longbob+Longsen&paymentCardExpiry=0520&paymentCardCSC=[FILTERED]&merchantUUID=51f7da294af8f&apiKey=[FILTERED]&method=processCard'
  end

  def soft_descriptor_options
    {
      descriptor_name: 'FOO*Test',
      descriptor_city: 'Melbourne',
      descriptor_state: 'VIC'
    }
  end
end
