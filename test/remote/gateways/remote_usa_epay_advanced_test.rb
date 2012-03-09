require 'test_helper'
require 'logger'

class RemoteUsaEpayAdvancedTest < Test::Unit::TestCase
  def setup
    @gateway = UsaEpayAdvancedGateway.new(fixtures(:usa_epay_advanced))

    @amount = 2111

    @credit_card = ActiveMerchant::Billing::CreditCard.new(
      :number => '4000100011112224',
      :month => 9,
      :year => 14,
      :brand => 'visa',
      :verification_value => '123',
      :first_name => "Fred",
      :last_name => "Flintstone"
    )

    @bad_credit_card = ActiveMerchant::Billing::CreditCard.new(
      :number => '4000300011112220',
      :month => 9,
      :year => 14,
      :brand => 'visa',
      :verification_value => '999',
      :first_name => "Fred",
      :last_name => "Flintstone"
    )

    @check = ActiveMerchant::Billing::Check.new(
      :account_number => '123456789',
      :routing_number => '120450780',
      :account_type => 'checking',
      :first_name => "Fred",
      :last_name => "Flintstone"
    )

    cc_method = [
      {:name => "My CC", :sort => 5, :method => @credit_card},
      {:name => "Other CC", :sort => 12, :method => @credit_card}
    ]

    @options = {
      :client_ip => '127.0.0.1',
      :billing_address => address,
    }

    @transaction_options = {
      :order_id => '1',
      :description => 'Store Purchase'
    }

    @customer_options = {
      :id => 123,
      :notes => "Customer note.",
      :data => "complex data",
      :url => "somesite.com",
      :payment_methods => cc_method
    }

    @update_customer_options = {
      :notes => "NEW NOTE!"
    }

    @add_payment_options = {
      :make_default => true,
      :payment_method => {
        :name => "My new card.",
        :sort => 10,
        :method => @credit_card
      }
    }

    @run_transaction_options = {
      :payment_method => @credit_card,
      :command => 'sale',
      :amount => 10000
    }

    @run_transaction_check_options = {
      :payment_method => @check,
      :command => 'check',
      :amount => 10000
    }

    @run_sale_options = {
      :payment_method => @credit_card,
      :amount => 5000
    }

    @run_check_sale_options = {
      :payment_method => @check,
      :amount => 2500
    }

    payment_methods = [
      {
        :name => "My Visa", # optional
        :sort => 2, # optional
        :method => @credit_card
      },
      {
        :name => "My Checking",
        :method => @check
      }
    ]
  end

  # Standard Gateway ==================================================

  def test_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'A', response.params['run_sale_return']['result_code']
  end

  def test_authorize
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert response.params['run_auth_only_return']
  end

  def test_capture
    auth = @gateway.authorize(@amount, @credit_card, @options.dup)

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_equal 'A', capture.params['capture_transaction_return']['result_code']
  end

  def test_void
    assert purchase = @gateway.purchase(@amount, @credit_card, @options.dup)

    assert credit = @gateway.void(purchase.authorization, @options)
    assert_equal 'true', credit.params['void_transaction_return']
  end

  def test_credit
    assert purchase = @gateway.purchase(@amount, @credit_card, @options.dup)

    assert_deprecation_warning(Gateway::CREDIT_DEPRECATION_MESSAGE, @gateway) do
      assert credit = @gateway.credit(@amount, purchase.authorization, @options)
      assert_equal 'A', credit.params['refund_transaction_return']['result_code']
    end
  end

  def test_refund
    assert purchase = @gateway.purchase(@amount, @credit_card, @options.dup)

    assert credit = @gateway.refund(@amount, purchase.authorization, @options)
    assert_equal 'A', credit.params['refund_transaction_return']['result_code']
  end

  def test_invalid_login
    gateway = UsaEpayAdvancedGateway.new(
                :login => '',
                :password => '',
                :software_id => ''
              )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Invalid software ID', response.message
  end

  # Customer ==========================================================

  def test_add_customer
    response = @gateway.add_customer(@options.merge(@customer_options))
    assert response.params['add_customer_return']
  end

  def test_update_customer
    response = @gateway.add_customer(@options.merge(@customer_options))
    customer_number = response.params['add_customer_return']

    @options.merge!(@update_customer_options.merge!(:customer_number => customer_number))
    response = @gateway.update_customer(@options)
    assert response.params['update_customer_return']
  end

  def test_enable_disable_customer
    response = @gateway.add_customer(@options.merge(@customer_options))
    customer_number = response.params['add_customer_return']

    response = @gateway.enable_customer(:customer_number => customer_number)
    assert response.params['enable_customer_return']

    response = @gateway.disable_customer(:customer_number => customer_number)
    assert response.params['disable_customer_return']
  end

  def test_add_customer_payment_method
    response = @gateway.add_customer(@options.merge(@customer_options))
    customer_number = response.params['add_customer_return']

    @options.merge!(:customer_number => customer_number).merge!(@add_payment_options)
    response = @gateway.add_customer_payment_method(@options)
    assert response.params['add_customer_payment_method_return']
  end

  def test_add_customer_payment_method_verify
    response = @gateway.add_customer(@options.merge(@customer_options))
    customer_number = response.params['add_customer_return']

    @add_payment_options[:payment_method][:method] = @bad_credit_card
    @options.merge!(:customer_number => customer_number, :verify => true).merge!(@add_payment_options)
    response = @gateway.add_customer_payment_method(@options)
    assert response.params['faultstring']
  end

  def test_get_customer_payment_methods
    response = @gateway.add_customer(@options.merge(@customer_options))
    customer_number = response.params['add_customer_return']

    response = @gateway.get_customer_payment_methods(:customer_number => customer_number)
    assert response.params['get_customer_payment_methods_return']['item']
  end

  def test_get_customer_payment_method
    response = @gateway.add_customer(@options.merge(@customer_options))
    customer_number = response.params['add_customer_return']

    response = @gateway.get_customer_payment_methods(:customer_number => customer_number)
    id = response.params['get_customer_payment_methods_return']['item'][0]['method_id']

    response = @gateway.get_customer_payment_method(:customer_number => customer_number, :method_id => id)
    assert response.params['get_customer_payment_method_return']
  end

  def test_update_customer_payment_method
    response = @gateway.add_customer(@options.merge(@customer_options))
    customer_number = response.params['add_customer_return']

    @options.merge!(:customer_number => customer_number).merge!(@add_payment_options)
    response = @gateway.add_customer_payment_method(@options)
    payment_method_id = response.params['add_customer_payment_method_return']

    update_payment_options = @add_payment_options[:payment_method].merge(:method_id => payment_method_id,
                                                                         :name => "Updated Card.")

    response = @gateway.update_customer_payment_method(update_payment_options)
    assert response.params['update_customer_payment_method_return']
  end

  def test_delete_customer_payment_method
    response = @gateway.add_customer(@options.merge(@customer_options))
    customer_number = response.params['add_customer_return']

    @options.merge!(:customer_number => customer_number).merge!(@add_payment_options)
    response = @gateway.add_customer_payment_method(@options)
    id = response.params['add_customer_payment_method_return']

    response = @gateway.delete_customer_payment_method(:customer_number => customer_number, :method_id => id)
    assert response.params['delete_customer_payment_method_return']
  end

  def test_delete_customer
    response = @gateway.add_customer(@options.merge(@customer_options))
    customer_number = response.params['add_customer_return']

    response = @gateway.delete_customer(:customer_number => customer_number)
    assert response.params['delete_customer_return']
  end

  def test_run_customer_transaction
    response = @gateway.add_customer(@options.merge(@customer_options))
    customer_number = response.params['add_customer_return']

    response = @gateway.run_customer_transaction(:customer_number => customer_number,# :method_id => 0, # optional
                                                 :command => "Sale", :amount => 3000)
    assert response.params['run_customer_transaction_return']
  end

  # Transactions ======================================================

  def test_run_transaction
    @options.merge!(@run_transaction_options)
    response = @gateway.run_transaction(@options)
    assert response.params['run_transaction_return']
    assert response.success?
  end

  def test_run_transaction_check
    @options.merge!(@run_transaction_check_options)
    response = @gateway.run_transaction(@options)
    assert response.params['run_transaction_return']
    assert response.success?
  end

  def test_run_sale
    @options.merge!(@run_sale_options)
    response = @gateway.run_sale(@options)
    assert response.params['run_sale_return']
  end

  def test_run_auth_only
    @options.merge!(@run_sale_options)
    response = @gateway.run_auth_only(@options)
    assert response.params['run_auth_only_return']
  end

  def test_run_credit
    @options.merge!(@run_sale_options)
    response = @gateway.run_credit(@options)
    assert response.params['run_credit_return']
  end

  def test_run_check_sale
    @options.merge!(@run_check_sale_options)
    response = @gateway.run_check_sale(@options)
    assert response.params['run_check_sale_return']
  end

  def test_run_check_credit
    @options.merge!(@run_check_sale_options)
    response = @gateway.run_check_credit(@options)
    assert response.params['run_check_credit_return']
  end

  # TODO get offline auth_code?
  def test_post_auth
    @options.merge!(:authorization_code => 123456)
    response = @gateway.post_auth(@options)
    assert response.params['post_auth_return']
  end

  def test_capture_transaction
    options = @options.merge(@run_sale_options)
    response = @gateway.run_auth_only(options)
    reference_number = response.params['run_auth_only_return']['ref_num']

    options = @options.merge(:reference_number => reference_number)
    response = @gateway.capture_transaction(options)
    assert response.params['capture_transaction_return']
  end

  def test_void_transaction
    options = @options.merge(@run_sale_options)
    response = @gateway.run_sale(options)
    reference_number = response.params['run_sale_return']['ref_num']

    options = @options.merge(:reference_number => reference_number)
    response = @gateway.void_transaction(options)
    assert response.params['void_transaction_return']
  end

  def test_refund_transaction
    options = @options.merge(@run_sale_options)
    response = @gateway.run_sale(options)
    reference_number = response.params['run_sale_return']['ref_num']

    options = @options.merge(:reference_number => reference_number, :amount => 0)
    response = @gateway.refund_transaction(options)
    assert response.params['refund_transaction_return']
  end

  # TODO how to test override_transaction
  def test_override_transaction
    options = @options.merge(@run_check_sale_options)
    response = @gateway.run_check_sale(options)
    reference_number = response.params['run_check_sale_return']['ref_num']

    response = @gateway.override_transaction(:reference_number => reference_number, :reason => "Because I said so")
    assert response.params['faultstring']
  end

  def test_run_quick_sale
    @options.merge!(@run_sale_options)
    response = @gateway.run_sale(@options)
    reference_number = response.params['run_sale_return']['ref_num']

    response = @gateway.run_quick_sale(:reference_number => reference_number, :amount => 9900)
    assert response.params['run_quick_sale_return']
  end

  def test_run_quick_sale_check
    @options.merge!(@run_check_sale_options)
    response = @gateway.run_check_sale(@options)
    reference_number = response.params['run_check_sale_return']['ref_num']

    response = @gateway.run_quick_sale(:reference_number => reference_number, :amount => 9900)
    assert response.params['run_quick_sale_return']
  end

  def test_run_quick_credit
    @options.merge!(@run_sale_options)
    response = @gateway.run_sale(@options)
    reference_number = response.params['run_sale_return']['ref_num']

    response = @gateway.run_quick_credit(:reference_number => reference_number, :amount => 0)
    assert response.params['run_quick_credit_return']
  end

  def test_run_quick_credit_check
    @options.merge!(@run_check_sale_options)
    response = @gateway.run_check_sale(@options)
    reference_number = response.params['run_check_sale_return']['ref_num']

    response = @gateway.run_quick_credit(:reference_number => reference_number, :amount => 1234)
    assert response.params['run_quick_credit_return']
  end

  # Transaction Status ===============================================

  def test_get_transaction
    response = @gateway.run_sale(@options.merge(@run_sale_options))
    reference_number = response.params['run_sale_return']['ref_num']

    response = @gateway.get_transaction(:reference_number => reference_number)
    assert response.params['get_transaction_return']
  end

  def test_get_transaction_status
    response = @gateway.run_sale(@options.merge(@run_sale_options))
    reference_number = response.params['run_sale_return']['ref_num']

    response = @gateway.get_transaction_status(:reference_number => reference_number)
    assert response.params['get_transaction_status_return']
  end

  def test_get_transaction_custom
    response = @gateway.run_sale(@options.merge(@run_sale_options))
    reference_number = response.params['run_sale_return']['ref_num']

    response = @gateway.get_transaction_custom(:reference_number => reference_number,
                                               :fields => ['Response.StatusCode', 'Response.Status'])
    assert response.params['get_transaction_custom_return']
    response = @gateway.get_transaction_custom(:reference_number => reference_number, 
                                               :fields => ['Response.StatusCode'])
    assert response.params['get_transaction_custom_return']
  end

  def test_get_check_trace
    response = @gateway.run_check_sale(@options.merge(@run_check_sale_options))
    reference_number = response.params['run_check_sale_return']['ref_num']

    response = @gateway.get_check_trace(:reference_number => reference_number)
    assert response.params['get_check_trace_return']
  end

  # Account ===========================================================

  # PASSING
  def test_get_account_details
    response = @gateway.get_account_details
    assert response.params['get_account_details_return']
  end
end
