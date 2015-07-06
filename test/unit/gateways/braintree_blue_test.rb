require 'test_helper'

class BraintreeBlueTest < Test::Unit::TestCase
  def setup
    @old_verbose, $VERBOSE = $VERBOSE, false

    @gateway = BraintreeBlueGateway.new(
      :merchant_id => 'test',
      :public_key => 'test',
      :private_key => 'test'
    )

    @internal_gateway = @gateway.instance_variable_get( :@braintree_gateway )
  end

  def teardown
    $VERBOSE = @old_verbose
  end

  def test_refund_legacy_method_signature
    Braintree::TransactionGateway.any_instance.expects(:refund).
      with('transaction_id', nil).
      returns(braintree_result(:id => "refund_transaction_id"))
    response = @gateway.refund('transaction_id', :test => true)
    assert_equal "refund_transaction_id", response.authorization
  end

  def test_refund_method_signature
    Braintree::TransactionGateway.any_instance.expects(:refund).
      with('transaction_id', '10.00').
      returns(braintree_result(:id => "refund_transaction_id"))
    response = @gateway.refund(1000, 'transaction_id', :test => true)
    assert_equal "refund_transaction_id", response.authorization
  end

  def test_transaction_uses_customer_id_by_default
    Braintree::TransactionGateway.any_instance.expects(:sale).
      with(has_entries(:customer_id => "present")).
      returns(braintree_result)

    assert response = @gateway.purchase(10, 'present', {})
    assert_instance_of Response, response
    assert_success response
  end

  def test_transaction_uses_payment_method_token_when_option
    Braintree::TransactionGateway.any_instance.expects(:sale).
      with(has_entries(:payment_method_token => "present")).
      returns(braintree_result)

    assert response = @gateway.purchase(10, 'present', { payment_method_token: true })
    assert_instance_of Response, response
    assert_success response
  end

  def test_transaction_uses_payment_method_nonce_when_option
    Braintree::TransactionGateway.any_instance.expects(:sale).
      with(has_entries(:payment_method_nonce => "present")).
      returns(braintree_result)

    assert response = @gateway.purchase(10, 'present', { payment_method_nonce: true })
    assert_instance_of Response, response
    assert_success response
  end

  def test_void_transaction
    Braintree::TransactionGateway.any_instance.expects(:void).
      with('transaction_id').
      returns(braintree_result(:id => "void_transaction_id"))

    response = @gateway.void('transaction_id', :test => true)
    assert_equal "void_transaction_id", response.authorization
  end

  def test_user_agent_includes_activemerchant_version
    assert @internal_gateway.config.user_agent.include?("(ActiveMerchant #{ActiveMerchant::VERSION})")
  end

  def test_merchant_account_id_present_when_provided_on_gateway_initialization
    @gateway = BraintreeBlueGateway.new(
      :merchant_id => 'test',
      :merchant_account_id => 'present',
      :public_key => 'test',
      :private_key => 'test'
    )

    Braintree::TransactionGateway.any_instance.expects(:sale).
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

    Braintree::TransactionGateway.any_instance.expects(:sale).
      with(has_entries(:merchant_account_id => "account_on_transaction")).
      returns(braintree_result)

    @gateway.authorize(100, credit_card("41111111111111111111"), :merchant_account_id => "account_on_transaction")
  end

  def test_merchant_account_id_present_when_provided
    Braintree::TransactionGateway.any_instance.expects(:sale).
      with(has_entries(:merchant_account_id => "present")).
      returns(braintree_result)

    @gateway.authorize(100, credit_card("41111111111111111111"), :merchant_account_id => "present")
  end

  def test_merchant_account_id_absent_if_not_provided
    Braintree::TransactionGateway.any_instance.expects(:sale).with do |params|
      not params.has_key?(:merchant_account_id)
    end.returns(braintree_result)

    @gateway.authorize(100, credit_card("41111111111111111111"))
  end

  def test_verification_merchant_account_id_exists_when_verify_card_and_merchant_account_id
    gateway = BraintreeBlueGateway.new(
      :merchant_id => 'merchant_id',
      :merchant_account_id => 'merchant_account_id',
      :public_key => 'public_key',
      :private_key => 'private_key'
    )
    customer = stub(
      :credit_cards => [stub_everything],
      :email => 'email',
      :first_name => 'John',
      :last_name => 'Smith'
    )
    customer.stubs(:id).returns('123')
    result = Braintree::SuccessfulResult.new(:customer => customer)

    Braintree::CustomerGateway.any_instance.expects(:create).with do |params|
      'merchant_account_id' == params[:credit_card][:options][:verification_merchant_account_id]
    end.returns(result)

    gateway.store(credit_card('41111111111111111111'), :verify_card => true)
  end

  def test_merchant_account_id_can_be_set_by_options
    gateway = BraintreeBlueGateway.new(
      :merchant_id => 'merchant_id',
      :merchant_account_id => 'merchant_account_id',
      :public_key => 'public_key',
      :private_key => 'private_key'
    )
    customer = stub(
      :credit_cards => [stub_everything],
      :email => 'email',
      :first_name => 'John',
      :last_name => 'Smith'
    )
    customer.stubs(:id).returns('123')
    result = Braintree::SuccessfulResult.new(:customer => customer)
    Braintree::CustomerGateway.any_instance.expects(:create).with do |params|
      'value_from_options' == params[:credit_card][:options][:verification_merchant_account_id]
    end.returns(result)

    gateway.store(credit_card('41111111111111111111'), :verify_card => true, :verification_merchant_account_id => 'value_from_options')
  end

  def test_store_with_verify_card_true
    customer = stub(
      :credit_cards => [stub_everything],
      :email => 'email',
      :first_name => 'John',
      :last_name => 'Smith'
    )
    customer.stubs(:id).returns('123')
    result = Braintree::SuccessfulResult.new(:customer => customer)
    Braintree::CustomerGateway.any_instance.expects(:create).with do |params|
      params[:credit_card][:options].has_key?(:verify_card)
      assert_equal true, params[:credit_card][:options][:verify_card]
      assert_equal "Longbob Longsen", params[:credit_card][:cardholder_name]
      params
    end.returns(result)

    response = @gateway.store(credit_card("41111111111111111111"), :verify_card => true)
    assert_equal "123", response.params["customer_vault_id"]
    assert_equal response.params["customer_vault_id"], response.authorization
  end

  def test_passes_email
    customer = stub(
      :credit_cards => [stub_everything],
      :email => "bob@example.com",
      :first_name => 'John',
      :last_name => 'Smith',
      id: "123"
    )
    result = Braintree::SuccessfulResult.new(:customer => customer)
    Braintree::CustomerGateway.any_instance.expects(:create).with do |params|
      assert_equal "bob@example.com", params[:email]
      params
    end.returns(result)

    response = @gateway.store(credit_card("41111111111111111111"), :email => "bob@example.com")
    assert_success response
  end

  def test_scrubs_invalid_email
    customer = stub(
      :credit_cards => [stub_everything],
      :email => nil,
      :first_name => 'John',
      :last_name => 'Smith',
      :id => "123"
    )
    result = Braintree::SuccessfulResult.new(:customer => customer)
    Braintree::CustomerGateway.any_instance.expects(:create).with do |params|
      assert_equal nil, params[:email]
      params
    end.returns(result)

    response = @gateway.store(credit_card("41111111111111111111"), :email => "bogus")
    assert_success response
  end

  def test_store_with_verify_card_false
    customer = stub(
      :credit_cards => [stub_everything],
      :email => 'email',
      :first_name => 'John',
      :last_name => 'Smith'
    )
    customer.stubs(:id).returns('123')
    result = Braintree::SuccessfulResult.new(:customer => customer)
    Braintree::CustomerGateway.any_instance.expects(:create).with do |params|
      params[:credit_card][:options].has_key?(:verify_card)
      assert_equal false, params[:credit_card][:options][:verify_card]
      params
    end.returns(result)

    response = @gateway.store(credit_card("41111111111111111111"), :verify_card => false)
    assert_equal "123", response.params["customer_vault_id"]
    assert_equal response.params["customer_vault_id"], response.authorization
  end

  def test_store_with_billing_address_options
    customer_attributes = {
      :credit_cards => [stub_everything],
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
    customer = stub(customer_attributes)
    customer.stubs(:id).returns('123')
    result = Braintree::SuccessfulResult.new(:customer => customer)
    Braintree::CustomerGateway.any_instance.expects(:create).with do |params|
      assert_not_nil params[:credit_card][:billing_address]
      [:street_address, :extended_address, :locality, :region, :postal_code, :country_name].each do |billing_attribute|
        params[:credit_card][:billing_address].has_key?(billing_attribute) if params[:billing_address]
      end
      params
    end.returns(result)

    @gateway.store(credit_card("41111111111111111111"), :billing_address => billing_address)
  end

  def test_store_with_credit_card_token
    customer = stub(
      :email => 'email',
      :first_name => 'John',
      :last_name => 'Smith'
    )
    customer.stubs(:id).returns('123')

    braintree_credit_card = stub_everything(token: "cctoken")
    customer.stubs(:credit_cards).returns([braintree_credit_card])

    result = Braintree::SuccessfulResult.new(:customer => customer)
    Braintree::CustomerGateway.any_instance.expects(:create).with do |params|
      assert_equal "cctoken", params[:credit_card][:token]
      params
    end.returns(result)

    response = @gateway.store(credit_card("41111111111111111111"), :credit_card_token => "cctoken")
    assert_success response
    assert_equal "cctoken", response.params["braintree_customer"]["credit_cards"][0]["token"]
    assert_equal "cctoken", response.params["credit_card_token"]
  end

  def test_store_with_customer_id
    customer = stub(
      :email => 'email',
      :first_name => 'John',
      :last_name => 'Smith',
      :credit_cards => [stub_everything]
    )
    customer.stubs(:id).returns("customerid")

    result = Braintree::SuccessfulResult.new(:customer => customer)
    Braintree::CustomerGateway.any_instance.expects(:find).
      with("customerid").
      raises(Braintree::NotFoundError)
    Braintree::CustomerGateway.any_instance.expects(:create).with do |params|
      assert_equal "customerid", params[:id]
      params
    end.returns(result)

    response = @gateway.store(credit_card("41111111111111111111"), :customer => "customerid")
    assert_success response
    assert_equal "customerid", response.params["braintree_customer"]["id"]
  end

  def test_store_with_existing_customer_id
    credit_card = stub(
      customer_id: "customerid",
      token: "cctoken"
    )

    result = Braintree::SuccessfulResult.new(credit_card: credit_card)
    Braintree::CustomerGateway.any_instance.expects(:find).with("customerid")
    Braintree::CreditCardGateway.any_instance.expects(:create).with do |params|
      assert_equal "customerid", params[:customer_id]
      assert_equal "41111111111111111111", params[:number]
      assert_equal "Longbob Longsen", params[:cardholder_name]
      params
    end.returns(result)

    response = @gateway.store(credit_card("41111111111111111111"), customer: "customerid")
    assert_success response
    assert_nil response.params["braintree_customer"]
    assert_equal "customerid", response.params["customer_vault_id"]
    assert_equal "cctoken", response.params["credit_card_token"]
  end

  def test_update_with_cvv
    stored_credit_card = mock(:token => "token", :default? => true)
    customer = mock(:credit_cards => [stored_credit_card], :id => '123')
    Braintree::CustomerGateway.any_instance.stubs(:find).with('vault_id').returns(customer)
    BraintreeBlueGateway.any_instance.stubs(:customer_hash)

    result = Braintree::SuccessfulResult.new(:customer => customer)
    Braintree::CustomerGateway.any_instance.expects(:update).with do |vault, params|
      assert_equal "567", params[:credit_card][:cvv]
      assert_equal "Longbob Longsen", params[:credit_card][:cardholder_name]
      [vault, params]
    end.returns(result)

    @gateway.update('vault_id', credit_card("41111111111111111111", :verification_value => "567"))
  end

  def test_update_with_verify_card_true
    stored_credit_card = stub(:token => "token", :default? => true)
    customer = stub(:credit_cards => [stored_credit_card], :id => '123')
    Braintree::CustomerGateway.any_instance.stubs(:find).with('vault_id').returns(customer)
    BraintreeBlueGateway.any_instance.stubs(:customer_hash)

    result = Braintree::SuccessfulResult.new(:customer => customer)
    Braintree::CustomerGateway.any_instance.expects(:update).with do |vault, params|
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
    Braintree::TransactionGateway.any_instance.expects(:sale).with do |params|
      (params[:billing][:country_code_alpha2] == "US")
    end.returns(braintree_result)
    @gateway.purchase(100, credit_card("41111111111111111111"), :billing_address => {:country => "US"})

    Braintree::TransactionGateway.any_instance.expects(:sale).with do |params|
      (params[:billing][:country_code_alpha2] == "US")
    end.returns(braintree_result)
    @gateway.purchase(100, credit_card("41111111111111111111"), :billing_address => {:country_code_alpha2 => "US"})

    Braintree::TransactionGateway.any_instance.expects(:sale).with do |params|
      (params[:billing][:country_name] == "United States of America")
    end.returns(braintree_result)
    @gateway.purchase(100, credit_card("41111111111111111111"), :billing_address => {:country_name => "United States of America"})

    Braintree::TransactionGateway.any_instance.expects(:sale).with do |params|
      (params[:billing][:country_code_alpha3] == "USA")
    end.returns(braintree_result)
    @gateway.purchase(100, credit_card("41111111111111111111"), :billing_address => {:country_code_alpha3 => "USA"})

    Braintree::TransactionGateway.any_instance.expects(:sale).with do |params|
      (params[:billing][:country_code_numeric] == 840)
    end.returns(braintree_result)
    @gateway.purchase(100, credit_card("41111111111111111111"), :billing_address => {:country_code_numeric => 840})
  end

  def test_address_zip_handling
    Braintree::TransactionGateway.any_instance.expects(:sale).with do |params|
      (params[:billing][:postal_code] == "12345")
    end.returns(braintree_result)
    @gateway.purchase(100, credit_card("41111111111111111111"), :billing_address => {:zip => "12345"})

    Braintree::TransactionGateway.any_instance.expects(:sale).with do |params|
      (params[:billing][:postal_code] == nil)
    end.returns(braintree_result)
    @gateway.purchase(100, credit_card("41111111111111111111"), :billing_address => {:zip => "1234567890"})
  end

  def test_passes_recurring_flag
    @gateway = BraintreeBlueGateway.new(
      :merchant_id => 'test',
      :merchant_account_id => 'present',
      :public_key => 'test',
      :private_key => 'test'
    )

    Braintree::TransactionGateway.any_instance.expects(:sale).
      with(has_entries(:recurring => true)).
      returns(braintree_result)

    @gateway.purchase(100, credit_card("41111111111111111111"), :recurring => true)

    Braintree::TransactionGateway.any_instance.expects(:sale).
      with(Not(has_entries(:recurring => true))).
      returns(braintree_result)

    @gateway.purchase(100, credit_card("41111111111111111111"))
  end

  def test_configured_logger_has_a_default
    # The default is actually provided by the Braintree gem, but we
    # assert its presence in order to show ActiveMerchant need not
    # configure a logger
    assert @internal_gateway.config.logger.is_a?(Logger)
  end

  def test_configured_logger_has_a_default_log_level_defined_by_active_merchant
    assert_equal Logger::WARN, @internal_gateway.config.logger.level
  end

  def test_default_logger_sets_warn_level_without_overwriting_global
    with_braintree_configuration_restoration do
      assert Braintree::Configuration.logger.level != Logger::DEBUG
      Braintree::Configuration.logger.level = Logger::DEBUG

      # Re-instantiate a gateway to show it doesn't touch the global
      gateway = BraintreeBlueGateway.new(
        :merchant_id => 'test',
        :public_key => 'test',
        :private_key => 'test'
      )
      internal_gateway = gateway.instance_variable_get(:@braintree_gateway)

      assert_equal Logger::WARN, internal_gateway.config.logger.level
      assert_equal Logger::DEBUG, Braintree::Configuration.logger.level
    end
  end

  def test_that_setting_a_wiredump_device_on_the_gateway_sets_the_braintree_logger_upon_instantiation
    with_braintree_configuration_restoration do
      logger = Logger.new(STDOUT)
      ActiveMerchant::Billing::BraintreeBlueGateway.wiredump_device = logger

      assert_not_equal logger, Braintree::Configuration.logger

      gateway = BraintreeBlueGateway.new(
        :merchant_id => 'test',
        :public_key => 'test',
        :private_key => 'test'
      )
      internal_gateway = gateway.instance_variable_get(:@braintree_gateway)

      assert_equal logger, internal_gateway.config.logger
      assert_equal Logger::DEBUG, internal_gateway.config.logger.level
    end
  end

  def test_solution_id_is_added_to_create_transaction_parameters
    assert_nil @gateway.send(:create_transaction_parameters, 100, credit_card("41111111111111111111"),{})[:channel]
    ActiveMerchant::Billing::BraintreeBlueGateway.application_id = 'ABC123'
    assert_equal @gateway.send(:create_transaction_parameters, 100, credit_card("41111111111111111111"),{})[:channel], "ABC123"
  ensure
    ActiveMerchant::Billing::BraintreeBlueGateway.application_id = nil
  end

  def test_successful_purchase_with_descriptor
    Braintree::TransactionGateway.any_instance.expects(:sale).with do |params|
      (params[:descriptor][:name] == 'wow*productname') &&
      (params[:descriptor][:phone] == '4443331112')
    end.returns(braintree_result)
    @gateway.purchase(100, credit_card("41111111111111111111"), descriptor_name: 'wow*productname', descriptor_phone: '4443331112')
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
