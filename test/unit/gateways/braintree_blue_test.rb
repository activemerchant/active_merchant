require 'test_helper'

class BraintreeBlueTest < Test::Unit::TestCase

  def setup
    @gateway = BraintreeBlueGateway.new(
      :merchant_id => 'test',
      :public_key => 'test',
      :private_key => 'test'
    )
  end

  def test_refund_legacy_method_signature
    Braintree::Transaction.expects(:refund).
      with('transaction_id', nil).
      returns(braintree_result(:id => "refund_transaction_id"))
    response = @gateway.refund('transaction_id', :test => true)
    assert_equal "refund_transaction_id", response.authorization
  end

  def test_refund_method_signature
    Braintree::Transaction.expects(:refund).
      with('transaction_id', '10.00').
      returns(braintree_result(:id => "refund_transaction_id"))
    response = @gateway.refund(1000, 'transaction_id', :test => true)
    assert_equal "refund_transaction_id", response.authorization
  end

  def test_void_transaction
    Braintree::Transaction.expects(:void).
      with('transaction_id').
      returns(braintree_result(:id => "void_transaction_id"))

    response = @gateway.void('transaction_id', :test => true)
    assert_equal "void_transaction_id", response.authorization
  end

  def test_user_agent_includes_activemerchant_version
    assert Braintree::Configuration.instantiate.user_agent.include?("(ActiveMerchant #{ActiveMerchant::VERSION})")
  end

  def test_merchant_account_id_present_when_provided_on_gateway_initialization
    @gateway = BraintreeBlueGateway.new(
      :merchant_id => 'test',
      :merchant_account_id => 'present',
      :public_key => 'test',
      :private_key => 'test'
    )

    Braintree::Transaction.expects(:sale).
      with(has_entries(:merchant_account_id => "present")).
      returns(braintree_result)

    @gateway.authorize(100, credit_card("41111111111111111111"))
  end

  def test_merchant_account_id_on_transaction_takes_precedence
    @gateway = BraintreeBlueGateway.new(
      :merchant_id => 'test',
      :merchant_account_id => 'present',
      :public_key => 'test',
      :private_key => 'test'
    )

    Braintree::Transaction.expects(:sale).
      with(has_entries(:merchant_account_id => "account_on_transaction")).
      returns(braintree_result)

    @gateway.authorize(100, credit_card("41111111111111111111"), :merchant_account_id => "account_on_transaction")
  end

  def test_merchant_account_id_present_when_provided
    Braintree::Transaction.expects(:sale).
      with(has_entries(:merchant_account_id => "present")).
      returns(braintree_result)

    @gateway.authorize(100, credit_card("41111111111111111111"), :merchant_account_id => "present")
  end

  def test_merchant_account_id_absent_if_not_provided
    Braintree::Transaction.expects(:sale).with do |params|
      not params.has_key?(:merchant_account_id)
    end.returns(braintree_result)

    @gateway.authorize(100, credit_card("41111111111111111111"))
  end

  def test_store_with_verify_card_true
    customer_attributes = {
      :credit_cards => [],
      :email => 'email',
      :first_name => 'John',
      :last_name => 'Smith',
      :id => "123"
    }
    result = Braintree::SuccessfulResult.new(:customer => mock(customer_attributes))
    Braintree::Customer.expects(:create).with do |params|
      params[:credit_card][:options].has_key?(:verify_card)
      assert_equal true, params[:credit_card][:options][:verify_card]
      params
    end.returns(result)
    
    @gateway.store(credit_card("41111111111111111111"), :verify_card => true)
  end

  def test_store_with_verify_card_false
    customer_attributes = {
      :credit_cards => [],
      :email => 'email',
      :first_name => 'John',
      :last_name => 'Smith',
      :id => "123"
    }
    result = Braintree::SuccessfulResult.new(:customer => mock(customer_attributes))
    Braintree::Customer.expects(:create).with do |params|
      params[:credit_card][:options].has_key?(:verify_card)
      assert_equal false, params[:credit_card][:options][:verify_card]
      params
    end.returns(result)
    
    @gateway.store(credit_card("41111111111111111111"), :verify_card => false)
  end

  def test_merge_credit_card_options_ignores_bad_option
    params = {:first_name => 'John', :credit_card => {:cvv => '123'}}
    options = {:verify_card => true, :bogus => 'ignore me'}
    merged_params = @gateway.send(:merge_credit_card_options, params, options)
    expected_params = {:first_name => 'John', :credit_card => {:cvv => '123', :options => {:verify_card => true}}}
    assert_equal expected_params, merged_params
  end

  def test_merge_credit_card_options_handles_nil_credit_card
    params = {:first_name => 'John'}
    options = {:verify_card => true, :bogus => 'ignore me'}
    merged_params = @gateway.send(:merge_credit_card_options, params, options)
    expected_params = {:first_name => 'John', :credit_card => {:options => {:verify_card => true}}}
    assert_equal expected_params, merged_params
  end

  private

  def braintree_result(options = {})
    Braintree::SuccessfulResult.new(:transaction => Braintree::Transaction._new(nil, {:id => "transaction_id"}.merge(options)))
  end
end
