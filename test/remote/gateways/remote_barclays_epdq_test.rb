require 'test_helper'

class RemoteBarclaysEpdqTest < Test::Unit::TestCase
  def setup
    @gateway = BarclaysEpdqGateway.new(fixtures(:barclays_epdq).merge(:test => true))

    @approved_amount = 3900
    @declined_amount = 4205
    @approved_card = credit_card('4715320629000001')
    @declined_card = credit_card('4715320629000027')

    @options = {
      :order_id => generate_unique_id,
      :billing_address => address,
      :description => 'Store Purchase'
    }

    @periodic_options = @options.merge(
      :payment_number => 1,
      :total_payments => 3,
      :group_id => 'MyTestPaymentGroup'
    )
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@approved_amount, @approved_card, @options)
    assert_success response
    assert_equal 'Approved.', response.message
    assert_equal @options[:order_id], response.authorization
    assert_no_match(/PaymentNoFraud/, response.params["raw_response"])
  end

  def test_successful_purchase_with_mastercard
    assert response = @gateway.purchase(@approved_amount, credit_card('5301250070000050', :brand => :master), @options)
    assert_success response
  end

  def test_successful_purchase_with_maestro
    assert response = @gateway.purchase(@approved_amount, credit_card('675938410597000022', :brand => :maestro, :issue_number => '5'), @options)
    assert_success response
  end

  def test_successful_purchase_with_switch
    assert response = @gateway.purchase(@approved_amount, credit_card('6759560045005727054', :brand => :switch, :issue_number => '1'), @options)
    assert_success response
  end

  def test_successful_purchase_with_minimal_options
    delete_address_details!

    assert response = @gateway.purchase(@approved_amount, @approved_card, @options)
    assert_success response
    assert_equal 'Approved.', response.message
    assert_equal @options[:order_id], response.authorization
    assert_no_match(/PaymentNoFraud/, response.params["raw_response"])
  end

  def test_successful_purchase_with_no_fraud
    @options[:no_fraud] = true
    assert response = @gateway.purchase(@approved_amount, @approved_card, @options)
    assert_success response
    assert_equal 'Approved.', response.message
    assert_equal @options[:order_id], response.authorization
    assert_match(/PaymentNoFraud/, response.params["raw_response"])
  end

  def test_successful_purchase_with_no_fraud_and_minimal_options
    delete_address_details!

    @options[:no_fraud] = true
    assert response = @gateway.purchase(@approved_amount, @approved_card, @options)
    assert_success response
    assert_equal 'Approved.', response.message
    assert_equal @options[:order_id], response.authorization
    assert_match(/PaymentNoFraud/, response.params["raw_response"])
  end

  def test_successful_purchase_with_no_address_or_order_id_or_description
    assert response = @gateway.purchase(@approved_amount, @approved_card, {})
    assert_success response
    assert_equal 'Approved.', response.message
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@declined_amount, @declined_card, @options)
    assert_failure response
    assert_match(/^Declined/, response.message)
  end

  def test_credit_new_order
    assert response = @gateway.credit(@approved_amount, @approved_card, @options)
    assert_success response
    assert_equal 'Approved.', response.message
  end

  def test_refund_existing_order
    assert response = @gateway.purchase(@approved_amount, @approved_card, @options)
    assert_success response

    assert refund = @gateway.refund(@approved_amount, response.authorization)
    assert_success refund
    assert_equal 'Approved.', refund.message
  end

  def test_refund_nonexisting_order_fails
    assert refund = @gateway.refund(@approved_amount, "DOESNOTEXIST", @options)
    assert_failure refund
    assert_match(/^Payment Mechanism CreditCard information not found/, refund.message)
  end

  def test_authorize_and_capture
    amount = @approved_amount
    assert auth = @gateway.authorize(amount, @approved_card, @options)
    assert_success auth
    assert_equal 'Approved.', auth.message
    assert auth.authorization
    assert_equal @options[:order_id], auth.authorization

    assert capture = @gateway.capture(amount, auth.authorization)
    assert_success capture
    assert_equal 'Approved.', capture.message
  end

  def test_authorize_and_capture_without_order_id
    @options.delete(:order_id)
    amount = @approved_amount
    assert auth = @gateway.authorize(amount, @approved_card, @options)
    assert_success auth
    assert_equal 'Approved.', auth.message
    assert auth.authorization
    assert_match(/[0-9a-f\-]{36}/, auth.authorization)

    assert capture = @gateway.capture(amount, auth.authorization)
    assert_success capture
    assert_equal 'Approved.', capture.message
  end

  def test_authorize_void_and_failed_capture
    amount = @approved_amount
    assert auth = @gateway.authorize(amount, @approved_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal 'Approved.', void.message

    assert capture = @gateway.capture(amount, auth.authorization)
    assert_failure capture
    assert_match(/^Did not find a unique, qualifying transaction for Order/, capture.message)
  end

  def test_failed_authorize
    assert auth = @gateway.authorize(@declined_amount, @approved_card, @options)
    assert_failure auth
    assert_match(/^Declined/, auth.message)
  end

  def test_failed_capture
    amount = @approved_amount
    assert auth = @gateway.authorize(amount, @approved_card, @options)
    assert_success auth

    @too_much = amount * 10
    assert capture = @gateway.capture(@too_much, auth.authorization)
    assert_success capture
    assert_match(/^The PostAuth is not valid because the amount/, capture.message)
  end

  def test_three_successful_periodic_orders
    amount = @approved_amount
    assert auth1 = @gateway.purchase(amount, @approved_card, @periodic_options)
    assert auth1.success?
    assert_equal 'Approved.', auth1.message

    @periodic_options[:payment_number] = 2
    @periodic_options[:order_id] = generate_unique_id
    assert auth2 = @gateway.purchase(amount, @approved_card, @periodic_options)
    assert auth2.success?
    assert_equal 'Approved.', auth2.message

    @periodic_options[:payment_number] = 3
    @periodic_options[:order_id] = generate_unique_id
    assert auth3 = @gateway.purchase(amount, @approved_card, @periodic_options)
    assert auth3.success?
    assert_equal 'Approved.', auth3.message
  end

  def test_invalid_login
    gateway = BarclaysEpdqGateway.new(
                :login => 'NOBODY',
                :password => 'HOME',
                :client_id => '1234'
              )
    assert response = gateway.purchase(@approved_amount, @approved_card, @options)
    assert_failure response
    assert_equal 'Insufficient permissions to perform requested operation.', response.message
  end

  protected
  def delete_address_details!
    @options[:billing_address].delete :city
    @options[:billing_address].delete :state
    @options[:billing_address].delete :country
    @options[:billing_address].delete :address1
    @options[:billing_address].delete :phone
    @options[:billing_address].delete :address1
    @options[:billing_address].delete :address2
    @options[:billing_address].delete :name
    @options[:billing_address].delete :fax
    @options[:billing_address].delete :company
  end
end
