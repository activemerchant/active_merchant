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
    customer = mock(
      :credit_cards => [],
      :email => 'email',
      :first_name => 'John',
      :last_name => 'Smith'
    )
    customer.stubs(:id).returns('123')
    result = Braintree::SuccessfulResult.new(:customer => customer)
    Braintree::Customer.expects(:create).with do |params|
      params[:credit_card][:options].has_key?(:verify_card)
      assert_equal true, params[:credit_card][:options][:verify_card]
      params
    end.returns(result)

    @gateway.store(credit_card("41111111111111111111"), :verify_card => true)
  end

  def test_store_with_verify_card_false
    customer = mock(
      :credit_cards => [],
      :email => 'email',
      :first_name => 'John',
      :last_name => 'Smith'
    )
    customer.stubs(:id).returns('123')
    result = Braintree::SuccessfulResult.new(:customer => customer)
    Braintree::Customer.expects(:create).with do |params|
      params[:credit_card][:options].has_key?(:verify_card)
      assert_equal false, params[:credit_card][:options][:verify_card]
      params
    end.returns(result)

    @gateway.store(credit_card("41111111111111111111"), :verify_card => false)
  end

  def test_store_with_billing_address_options
    customer_attributes = {
      :credit_cards => [],
      :email => 'email',
      :first_name => 'John',
      :last_name => 'Smith'
    }
    billing_address = {
      :address1 => "1 E Main St",
      :address2 => "Suite 403",
      :city => "Chicago",
      :state => "Illinois",
      :zip => "60622",
      :country_name => "US"
    }
    customer = mock(customer_attributes)
    customer.stubs(:id).returns('123')
    result = Braintree::SuccessfulResult.new(:customer => customer)
    Braintree::Customer.expects(:create).with do |params|
      assert_not_nil params[:credit_card][:billing_address]
      [:street_address, :extended_address, :locality, :region, :postal_code, :country_name].each do |billing_attribute|
        params[:credit_card][:billing_address].has_key?(billing_attribute) if params[:billing_address]
      end
      params
    end.returns(result)

    @gateway.store(credit_card("41111111111111111111"), :billing_address => billing_address)
  end

  def test_update_with_cvv
    stored_credit_card = mock(:token => "token", :default? => true)
    customer = mock(:credit_cards => [stored_credit_card], :id => '123')
    Braintree::Customer.stubs(:find).with('vault_id').returns(customer)
    BraintreeBlueGateway.any_instance.stubs(:customer_hash)

    result = Braintree::SuccessfulResult.new(:customer => customer)
    Braintree::Customer.expects(:update).with do |vault, params|
      assert_equal "567", params[:credit_card][:cvv]
      [vault, params]
    end.returns(result)

    @gateway.update('vault_id', credit_card("41111111111111111111", :verification_value => "567"))
  end

  def test_update_with_verify_card_true
    stored_credit_card = mock(:token => "token", :default? => true)
    customer = mock(:credit_cards => [stored_credit_card], :id => '123')
    Braintree::Customer.stubs(:find).with('vault_id').returns(customer)
    BraintreeBlueGateway.any_instance.stubs(:customer_hash)

    result = Braintree::SuccessfulResult.new(:customer => customer)
    Braintree::Customer.expects(:update).with do |vault, params|
      assert_equal true, params[:credit_card][:options][:verify_card]
      [vault, params]
    end.returns(result)

    @gateway.update('vault_id', credit_card("41111111111111111111"), :verify_card => true)
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

  def test_merge_credit_card_options_handles_billing_address
    billing_address = {
      :address1 => "1 E Main St",
      :city => "Chicago",
      :state => "Illinois",
      :zip => "60622",
      :country => "US"
    }
    params = {:first_name => 'John'}
    options = {:billing_address => billing_address}
    expected_params = {
      :first_name => 'John',
      :credit_card => {
        :billing_address => {
          :street_address => "1 E Main St",
          :extended_address => nil,
          :company => nil,
          :locality => "Chicago",
          :region => "Illinois",
          :postal_code => "60622",
          :country_code_alpha2 => "US"
        },
        :options => {}
      }
    }
    assert_equal expected_params, @gateway.send(:merge_credit_card_options, params, options)
  end

  def test_merge_credit_card_options_only_includes_billing_address_when_present
    params = {:first_name => 'John'}
    options = {}
    expected_params = {
      :first_name => 'John',
      :credit_card => {
        :options => {}
      }
    }
    assert_equal expected_params, @gateway.send(:merge_credit_card_options, params, options)
  end

  def test_address_country_handling
    Braintree::Transaction.expects(:sale).with do |params|
      (params[:billing][:country_code_alpha2] == "US")
    end.returns(braintree_result)
    @gateway.purchase(100, credit_card("41111111111111111111"), :billing_address => {:country => "US"})

    Braintree::Transaction.expects(:sale).with do |params|
      (params[:billing][:country_code_alpha2] == "US")
    end.returns(braintree_result)
    @gateway.purchase(100, credit_card("41111111111111111111"), :billing_address => {:country_code_alpha2 => "US"})

    Braintree::Transaction.expects(:sale).with do |params|
      (params[:billing][:country_name] == "United States of America")
    end.returns(braintree_result)
    @gateway.purchase(100, credit_card("41111111111111111111"), :billing_address => {:country_name => "United States of America"})

    Braintree::Transaction.expects(:sale).with do |params|
      (params[:billing][:country_code_alpha3] == "USA")
    end.returns(braintree_result)
    @gateway.purchase(100, credit_card("41111111111111111111"), :billing_address => {:country_code_alpha3 => "USA"})

    Braintree::Transaction.expects(:sale).with do |params|
      (params[:billing][:country_code_numeric] == 840)
    end.returns(braintree_result)
    @gateway.purchase(100, credit_card("41111111111111111111"), :billing_address => {:country_code_numeric => 840})
  end

  def test_passes_recurring_flag
    @gateway = BraintreeBlueGateway.new(
      :merchant_id => 'test',
      :merchant_account_id => 'present',
      :public_key => 'test',
      :private_key => 'test'
    )

    Braintree::Transaction.expects(:sale).
      with(has_entries(:recurring => true)).
      returns(braintree_result)

    @gateway.purchase(100, credit_card("41111111111111111111"), :recurring => true)

    Braintree::Transaction.expects(:sale).
      with(Not(has_entries(:recurring => true))).
      returns(braintree_result)

    @gateway.purchase(100, credit_card("41111111111111111111"))
  end

  def test_configured_logger_has_a_default
    # The default is actually provided by the Braintree gem, but we
    # assert its presence in order to show ActiveMerchant need not
    # configure a logger
    assert Braintree::Configuration.logger.is_a?(Logger)
  end

  def test_configured_logger_has_a_default_log_level_defined_by_braintree_gem
    assert_equal Logger::INFO, Braintree::Configuration.logger.level
  end

  def test_configured_logger_respects_any_custom_log_level_set_without_overwriting_it
    with_braintree_configuration_restoration do
      assert Braintree::Configuration.logger.level != Logger::DEBUG
      Braintree::Configuration.logger.level = Logger::DEBUG

      # Re-instatiate a gateway to show it doesn't affect the log level
      BraintreeBlueGateway.new(
        :merchant_id => 'test',
        :public_key => 'test',
        :private_key => 'test'
      )

      assert_equal Logger::DEBUG, Braintree::Configuration.logger.level
    end
  end

  def test_that_setting_a_wiredump_device_on_the_gateway_sets_the_braintree_logger_upon_instantiation
    with_braintree_configuration_restoration do
      logger = Logger.new(STDOUT)
      ActiveMerchant::Billing::BraintreeBlueGateway.wiredump_device = logger

      assert_not_equal logger, Braintree::Configuration.logger

      BraintreeBlueGateway.new(
        :merchant_id => 'test',
        :public_key => 'test',
        :private_key => 'test'
      )

      assert_equal logger, Braintree::Configuration.logger
      assert_equal Logger::DEBUG, Braintree::Configuration.logger.level
    end
  end

  private

  def braintree_result(options = {})
    Braintree::SuccessfulResult.new(:transaction => Braintree::Transaction._new(nil, {:id => "transaction_id"}.merge(options)))
  end

  def with_braintree_configuration_restoration(&block)
    # Remember the wiredump device since we may overwrite it
    existing_wiredump_device = ActiveMerchant::Billing::BraintreeBlueGateway.wiredump_device

    yield

    # Restore the wiredump device
    ActiveMerchant::Billing::BraintreeBlueGateway.wiredump_device = existing_wiredump_device

    # Reset the Braintree logger
    Braintree::Configuration.logger = nil
  end
end
