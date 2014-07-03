require 'test_helper'

class SamuraiTest < Test::Unit::TestCase
  def setup
    @old_verbose, $VERBOSE = $VERBOSE, false

    @gateway = SamuraiGateway.new(
              :login => "MERCHANT KEY",
              :password => "MERCHANT_PASSWORD",
              :processor_token => "PROCESSOR_TOKEN"
               )
    @successful_credit_card = credit_card
    @successful_payment_method_token = "successful_token"
    @amount = '1.00'
    @amount_cents = 100
    @successful_authorization_id = "successful_authorization_id"
  end

  def teardown
    $VERBOSE = @old_verbose
  end

  def test_successful_purchase_with_payment_method_token
    Samurai::Processor.expects(:purchase).
                       with(@successful_payment_method_token, @amount, {}).
                       returns(successful_purchase_response)

    response = @gateway.purchase(@amount_cents, @successful_payment_method_token, {})
    assert_instance_of Response, response
    assert_success response
    assert_equal "reference_id", response.authorization
  end

  def test_successful_authorize_with_payment_method_token
    Samurai::Processor.expects(:authorize).
                       with(@successful_payment_method_token, @amount, {}).
                       returns(successful_authorize_response)

    response = @gateway.authorize(@amount_cents, @successful_payment_method_token)
    assert_instance_of Response, response
    assert_success response
    assert_equal "reference_id", response.authorization
  end


  def test_successful_purchase_with_credit_card
    @gateway.expects(:store).
             with(@successful_credit_card, {}).
             returns(successful_store_result)

    Samurai::Processor.expects(:purchase).
              with(@successful_payment_method_token, @amount, {}).
              returns(successful_purchase_response)

    response = @gateway.purchase(@amount_cents, @successful_credit_card)
    assert_instance_of Response, response
    assert_success response
    assert_equal "reference_id", response.authorization
  end

  def test_successful_authorize_with_credit_card
    @gateway.expects(:store).
             with(@successful_credit_card, {}).
             returns(successful_store_result)

    Samurai::Processor.expects(:authorize).
              with(@successful_payment_method_token, @amount, {}).
              returns(successful_authorize_response)

    response = @gateway.authorize(@amount_cents, @successful_credit_card)
    assert_instance_of Response, response
    assert_success response
    assert_equal "reference_id", response.authorization
  end

  def test_successful_capture
    Samurai::Transaction.expects(:find).
                         with(@successful_authorization_id).
                         returns(transaction = successful_authorize_response)

    transaction.expects(:capture).
                with(@amount).
                returns(successful_capture_response)

    response = @gateway.capture(@amount_cents, @successful_authorization_id)
    assert_instance_of Response, response
    assert_success response
    assert_equal "reference_id", response.authorization
  end


  def test_successful_refund
    Samurai::Transaction.expects(:find).
                         with(@successful_authorization_id).
                         returns(transaction = successful_authorize_response)

    transaction.expects(:credit).
                with(@amount).
                returns(successful_credit_response)

    response = @gateway.refund(@amount_cents, @successful_authorization_id)
    assert_instance_of Response, response
    assert_success response
    assert_equal "reference_id", response.authorization
  end

  def test_successful_void
    Samurai::Transaction.expects(:find).
                         with(@successful_authorization_id).
                         returns(transaction = successful_authorize_response)

    transaction.expects(:void).returns(successful_void_response)

    response = @gateway.void(@successful_authorization_id)
    assert_instance_of Response, response
    assert_success response
    assert_equal "reference_id", response.authorization
  end

  def test_successful_store
    card_to_store = {
      :card_number  => "4242424242424242",
      :expiry_month => "09",
      :expiry_year  => (Time.now.year + 1).to_s,
      :cvv          => "123",
      :first_name   => "Longbob",
      :last_name    => "Longsen",
      :address_1    => nil,
      :address_2    => nil,
      :city         => nil,
      :zip          => nil,
      :sandbox      => true
    }
    Samurai::PaymentMethod.expects(:create).
                           with(card_to_store).
                           returns(successful_create_payment_method_response)
    response = @gateway.store(@successful_credit_card)
    assert_instance_of Response, response
    assert_success response
  end

  def test_successful_retain
    card_to_store = valid_credit_card
    payment_method = successful_create_payment_method_response
    Samurai::PaymentMethod.expects(:create).
                           with(card_to_store).
                           returns(payment_method)
    payment_method.expects(:retain)
    response = @gateway.store(@successful_credit_card, :retain => true)
    assert_instance_of Response, response
    assert_success response
  end

  def test_no_retain_on_failed_store
    card_to_store = valid_credit_card
    payment_method = successful_create_payment_method_response
    payment_method.is_sensitive_data_valid = false
    payment_method.payment_method_token = nil
    Samurai::PaymentMethod.expects(:create).
                           with(card_to_store).
                           returns(payment_method)
    payment_method.expects(:retain).never
    @gateway.store(@successful_credit_card, :retain => true)
  end

  def test_no_retain_options
    card_to_store = valid_credit_card
    payment_method = successful_create_payment_method_response
    Samurai::PaymentMethod.expects(:create).
                           with(card_to_store).
                           returns(payment_method).
                           twice
    payment_method.expects(:retain).never
    @gateway.store(@successful_credit_card, :retain => false)
    @gateway.store(@successful_credit_card)
  end

  def test_passing_optional_processor_options
    Samurai::Processor.expects(:purchase).
                       with(@successful_payment_method_token, @amount, {:billing_reference => 'billing_reference'}).
                       returns(successful_purchase_response)

    response = @gateway.purchase(@amount_cents, @successful_payment_method_token, {:billing_reference => 'billing_reference', :invalid_option => 'not_included'})
    assert_instance_of Response, response
    assert_success response
    assert_equal "reference_id", response.authorization
  end

  def test_successful_avs_and_cvv
    Samurai::Processor.expects(:purchase).
                       with(@successful_payment_method_token, @amount, {}).
                       returns(successful_purchase_response)

    response = @gateway.purchase(@amount_cents, @successful_payment_method_token)
    assert_instance_of Response, response
    assert_success response
    assert_equal "Y", response.avs_result["code"]
    assert_equal "M", response.cvv_result["code"]
  end

  private

  def valid_credit_card
    {
      :card_number  => "4242424242424242",
      :expiry_month => "09",
      :expiry_year  => (Time.now.year + 1).to_s,
      :cvv          => "123",
      :first_name   => "Longbob",
      :last_name    => "Longsen",
      :address_1    => nil,
      :address_2    => nil,
      :city         => nil,
      :zip          => nil,
      :sandbox      => true
    }
  end

  def successful_purchase_response
    successful_response("Purchase")
  end

  def successful_capture_response
    successful_response("Capture")
  end

  def successful_credit_response
    successful_response("Credit")
  end

  def successful_authorize_response
    successful_response("Authorize")
  end

  def successful_void_response
    successful_response("Void")
  end

  def successful_store_result
    Response.new(true, "message", {:payment_method_token => @successful_payment_method_token})
  end

  def successful_create_payment_method_response
    Samurai::PaymentMethod.new(:is_sensitive_data_valid => true, :payment_method_token => @successful_payment_method_token)
  end

  def successful_response(transaction_type, options = {})
    payment_method = Samurai::PaymentMethod.new(:payment_method_token => "payment_method_token")
    processor_response = Samurai::ProcessorResponse.new(:success => true,
          :messages => [{:context => 'processor.avs_result_code', :key => 'Y', :subclass => 'info'},
                        {:context => 'processor.cvv_result_code', :key => 'M', :subclass => 'info'}])
    Samurai::Transaction.new({
      :reference_id         => "reference_id",
      :transaction_token    => "transaction_token",
      :payment_method       => payment_method,
      :processor_response   => processor_response,
      :transaction_type     => transaction_type
    }.merge(options))
  end

end
