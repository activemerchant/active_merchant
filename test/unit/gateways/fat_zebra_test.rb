require 'test_helper'

class FatZebraTest < Test::Unit::TestCase
  def setup
    @gateway = FatZebraGateway.new(
                 :username => 'TEST',
                 :token    => 'TEST'
               )

    @credit_card = credit_card
    @amount = 100

    @options = {
      :order_id => rand(10000),
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_request).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal '001-P-12345AA', response.authorization
    assert response.test?
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_request).returns(failed_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
    assert_match /Invalid Card Number/, response.message
  end

  def test_declined_purchase
    @gateway.expects(:ssl_request).returns(declined_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
    assert_match /Card Declined/, response.message
  end

  def test_parse_error
    @gateway.expects(:ssl_request).returns("{") # Some invalid JSON
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match /Invalid JSON response/, response.message
  end

  def test_request_error
    @gateway.expects(:ssl_request).returns(missing_data_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match /Card Number is required/, response.message
  end

  def test_successful_tokenization
    @gateway.expects(:ssl_request).returns(successful_tokenize_response)

    assert response = @gateway.store(@credit_card)
    assert_success response
  end

  def test_unsuccessful_tokenization
    @gateway.expects(:ssl_request).returns(failed_tokenize_response)

    assert response = @gateway.store(@credit_card)
    assert_failure response
  end

  def test_successful_refund
    @gateway.expects(:ssl_request).returns(successful_refund_response)

    assert response = @gateway.refund(100, "TEST", "Test refund")
    assert_success response
    assert_equal '003-R-7MNIUMY6', response.authorization
    assert response.test?
  end

  def test_unsuccessful_refund
    @gateway.expects(:ssl_request).returns(unsuccessful_refund_response)

    assert response = @gateway.refund(100, "TEST", "Test refund")
    assert_failure response
    assert response.test?
  end

  private

  # Place raw successful response from gateway here
  def successful_purchase_response
    {
      :successful => true,
      :response => {
        :authorization => "55355",
        :id => "001-P-12345AA",
        :card_number => "XXXXXXXXXXXX1111",
        :card_holder => "John Smith",
        :card_expiry => "10/2011",
        :card_token => "a1bhj98j",
        :amount => 349,
        :successful => true,
        :reference => "ABC123",
        :message => "Approved",
      },
      :test => true,
      :errors => []
    }.to_json
  end

  def declined_purchase_response
    {
      :successful => true,
      :response => {
          :authorization_id => nil,
          :id => nil,
          :card_number => "XXXXXXXXXXXX1111",
          :card_holder => "John Smith",
          :card_expiry => "10/2011",
          :amount => 100,
          :authorized => false,
          :reference => "ABC123",
          :message => "Card Declined - check with issuer",
      },
      :test => true,
      :errors => [] 
    }.to_json
  end

  def successful_refund_response
    {
      :successful => true,
      :response => {
        :authorization => "1339973263",
        :id => "003-R-7MNIUMY6",
        :amount => -10,
        :refunded => "Approved",
        :message => "08 Approved",
        :card_holder => "Harry Smith",
        :card_number => "XXXXXXXXXXXX4444",
        :card_expiry => "2013-05-31",
        :card_type => "MasterCard",
        :transaction_id => "003-R-7MNIUMY6",
        :successful => true
      },
      :errors => [

      ],
      :test => true
    }.to_json
  end

  def unsuccessful_refund_response
    {
      :successful => false,
      :response => {
        :authorization => nil,
        :id => nil,
        :amount => nil,
        :refunded => nil,
        :message => nil,
        :card_holder => "Matthew Savage",
        :card_number => "XXXXXXXXXXXX4444",
        :card_expiry => "2013-05-31",
        :card_type => "MasterCard",
        :transaction_id => nil,
        :successful => false
      },
      :errors => [
        "Reference can't be blank"
      ],
      :test => true
    }.to_json
  end

  def successful_tokenize_response
    {
      :successful => true,
      :response => {
        :token => "e1q7dbj2",
        :card_holder => "Bob Smith",
        :card_number => "XXXXXXXXXXXX2346",
        :card_expiry => "2013-05-31T23:59:59+10:00",
        :authorized => true,
        :transaction_count => 0
      },
      :errors => [],
      :test => true
    }.to_json
  end

  def failed_tokenize_response
    {
      :successful => false,
      :response => {
        :token => nil,
        :card_holder => "Bob ",
        :card_number => "512345XXXXXX2346",
        :card_expiry => nil,
        :authorized => false,
        :transaction_count => 10
      },
      :errors => [
        "Expiry date can't be blank"
      ],
      :test => false
    }.to_json
  end

  # Place raw failed response from gateway here
  def failed_purchase_response
    {
      :successful => false,
      :response => {},
      :test => true,
      :errors => ["Invalid Card Number"]
    }.to_json
  end

  def missing_data_response
    {
      :successful => false,
      :response => {},
      :test => true,
      :errors => ["Card Number is required"]
    }.to_json
  end
end
