require 'test_helper'

class SamuraiTest < Test::Unit::TestCase
  def setup
    @gateway = SamuraiGateway.new(
              :merchant_key => "MERCHANT KEY",
              :merchant_password => "MERCHANT_PASSWORD",
              :processor_token => "PROCESSOR_TOKEN"
               )
    @successful_credit_card = credit_card()
    @successful_payment_method_token = "successful_token"
    @amount = 100
    @successful_authorization_id = "successful_authorization_id"
    @options = {
       :billing_reference   => "billing_reference",
       :customer_reference  => "customer_reference",
       :custom              => "custom",
       :descriptor          => "descriptor",
    }
  end


  def test_successful_purchase_with_payment_method_token
    Samurai::Processor.expects(:purchase).
                       with(@successful_payment_method_token, @amount, @options).
                       returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @successful_payment_method_token, @options)
    assert_instance_of Response, response
    assert response.success?, "Response failed: #{response.inspect}"
  end

  def test_successful_authorize_with_payment_method_token
    Samurai::Processor.expects(:authorize).
                       with(@successful_payment_method_token, @amount, @options).
                       returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @successful_payment_method_token, @options)
    assert_instance_of Response, response
    assert response.success?, "Response failed: #{response.inspect}"
  end


  def test_successful_purchase_with_credit_card
    @gateway.expects(:store).
             with(@successful_credit_card, @options).
             returns(successful_store_result)

    Samurai::Processor.expects(:purchase).
              with(@successful_payment_method_token, @amount, @options).
              returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @successful_credit_card, @options)
    assert_instance_of Response, response
    assert response.success?, "Response failed: #{response.inspect}"
  end

  def test_successful_authorize_with_credit_card
    @gateway.expects(:store).
             with(@successful_credit_card, @options).
             returns(successful_store_result)

    Samurai::Processor.expects(:authorize).
              with(@successful_payment_method_token, @amount, @options).
              returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @successful_credit_card, @options)
    assert_instance_of Response, response
    assert response.success?, "Response failed: #{response.inspect}"
  end

  def test_successful_capture
    Samurai::Transaction.expects(:find).
                         with(@successful_authorization_id).
                         returns(transaction = successful_authorize_response)

    transaction.expects(:capture).
                with(@amount).
                returns(successful_capture_response)

    response = @gateway.capture(@amount, @successful_authorization_id, @options)
    assert_instance_of Response, response
    assert response.success?, "Response failed: #{response.inspect}"
  end


  def test_successful_credit
    Samurai::Transaction.expects(:find).
                         with(@successful_authorization_id).
                         returns(transaction = successful_authorize_response)

    transaction.expects(:credit).
                with(@amount).
                returns(successful_credit_response)

    response = @gateway.credit(@amount, @successful_authorization_id, @options)
    assert_instance_of Response, response
    assert response.success?, "Response failed: #{response.inspect}"
  end

  def test_successful_store
    card_to_store = {
      :card_number  => "4242424242424242",
      :expiry_month => "09",
      :expiry_year  => "2012",
      :cvv          => "123",
      :first_name   => "Longbob",
      :last_name    => "Longsen",
      :address_1    => nil,
      :address_2    => nil,
      :city         => nil,
      :zip          => nil,
      :sandbox      => false
    }
    Samurai::PaymentMethod.expects(:create).
                           with(card_to_store).
                           returns(successful_create_payment_method_response)
    response = @gateway.store(@successful_credit_card, @options)
    assert_instance_of Response, response
    assert response.success?, "Response failed: #{response.inspect}"
  end

  private

  def successful_purchase_response
    payment_method = Samurai::PaymentMethod.new(:payment_method_token => "payment_method_token")
    processor_response = Samurai::ProcessorResponse.new(:avs_result_code => "Y", :success => true, :messages => [])
    Samurai::Transaction.new({
      :reference_id => "reference_id",
      :transaction_token => "transaction_token",
      :payment_method => payment_method,
      :processor_response => processor_response,
      :transaction_type => "Purchase"
    })
  end

  def successful_capture_response
    payment_method = Samurai::PaymentMethod.new(:payment_method_token => "payment_method_token")
    processor_response = Samurai::ProcessorResponse.new(:avs_result_code => "Y", :success => true, :messages => [])
    @transaction = Samurai::Transaction.new({
      :reference_id => "reference_id",
      :transaction_token => "transaction_token",
      :payment_method => payment_method,
      :processor_response => processor_response,
      :transaction_type => "Capture"
    })
  end

  def successful_credit_response
    payment_method = Samurai::PaymentMethod.new(:payment_method_token => "payment_method_token")
    processor_response = Samurai::ProcessorResponse.new(:success=>true, :messages => [])
    @transaction = Samurai::Transaction.new({
      :reference_id => "reference_id",
      :transaction_token => "transaction_token",
      :payment_method => payment_method,
      :processor_response => processor_response,
      :transaction_type => "Credit"
    })
  end

  def successful_store_result
    Response.new(true, "message", {:payment_method_token => @successful_payment_method_token})
  end

  def successful_create_payment_method_response
    Samurai::PaymentMethod.new(:is_sensitive_data_valid => true, :payment_method_token => @successful_payment_method_token)
  end


  def successful_authorize_response
    payment_method = Samurai::PaymentMethod.new(:payment_method_token => "payment_method_token")
    processor_response = Samurai::ProcessorResponse.new(:avs_result_code => "Y", :success => true, :messages => [])
    Samurai::Transaction.new({
      :reference_id => "reference_id",
      :transaction_token => "transaction_token",
      :payment_method => payment_method,
      :processor_response => processor_response,
      :transaction_type => "Authorize"
    })
  end

end