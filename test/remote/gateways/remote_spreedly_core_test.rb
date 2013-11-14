require 'test_helper'

class RemoteSpreedlyCoreTest < Test::Unit::TestCase

  def setup
    @gateway = SpreedlyCoreGateway.new(fixtures(:spreedly_core))

    @amount = 100
    @credit_card = credit_card('5555555555554444')
    @declined_card = credit_card('4012888888881881')
    @existing_payment_method = '9AjLflWs7SOKuqJLveOZya9bixa'
    @declined_payment_method = 'n3JElNt9joT1mJ3CxvWjyEN39N'
  end

  def test_successful_purchase_with_token
    assert response = @gateway.purchase(@amount, @existing_payment_method)
    assert_success response
    assert_equal 'Succeeded!', response.message
  end

  def test_failed_purchase_with_token
    assert response = @gateway.purchase(@amount, @declined_payment_method)
    assert_failure response
    assert_match %r(Unable to process the transaction), response.message
  end

  def test_successful_authorize_with_token_and_capture
    assert auth_response = @gateway.authorize(@amount, @existing_payment_method)
    assert_success auth_response
    assert_equal 'Succeeded!', auth_response.message
    assert auth_response.authorization

    assert capture_response = @gateway.capture(@amount, auth_response.authorization)
    assert_success capture_response
    assert_equal 'Succeeded!', capture_response.message
  end

  def test_failed_authorize_with_token
    assert response = @gateway.authorize(@amount, @declined_payment_method)
    assert_failure response
    assert_match %r(Unable to process the transaction), response.message
  end

  def test_failed_capture
    assert auth_response = @gateway.authorize(@amount, @existing_payment_method)
    assert_success auth_response

    assert capture_response = @gateway.capture(44, auth_response.authorization)
    assert_failure capture_response
    assert_equal 'Unable to process the capture transaction.', capture_response.message
  end

  def test_successful_purchase_with_credit_card
    assert response = @gateway.purchase(@amount, @credit_card)
    assert_success response
    assert_equal 'Succeeded!', response.message
    assert_equal 'Purchase', response.params['transaction_type']
    assert_equal 'used', response.params['payment_method_storage_state']
  end

  def test_successful_purchase_with_card_and_address
    options = {
      :email => 'joebob@example.com',
      :billing_address => address,
    }

    assert response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal 'Succeeded!', response.message

    assert_equal 'joebob@example.com', response.params['payment_method_email']
    assert_equal '1234 My Street', response.params['payment_method_address1']
    assert_equal 'Apt 1', response.params['payment_method_address2']
    assert_equal 'Ottawa', response.params['payment_method_city']
    assert_equal 'ON', response.params['payment_method_state']
    assert_equal 'K1C2N6', response.params['payment_method_zip']
  end

  def test_failed_purchase_with_declined_credit_card
    assert response = @gateway.purchase(@amount, @declined_card)
    assert_failure response
    assert_equal 'Unable to process the purchase transaction.', response.message
  end

  def test_failed_purchase_with_invalid_credit_card
    @credit_card.first_name = ' '
    assert response = @gateway.purchase(@amount, @credit_card)
    assert_failure response
    assert_equal "First name can't be blank", response.message
  end

  def test_successful_purchase_with_store
    assert response = @gateway.purchase(@amount, @credit_card, store: true)
    assert_success response
    assert_equal 'Succeeded!', response.message
    assert_equal 'Purchase', response.params['transaction_type']
    assert_equal 'retained', response.params['payment_method_storage_state']
    assert !response.params['payment_method_token'].blank?
  end

  def test_successful_authorize_and_capture_with_credit_card
    assert response = @gateway.authorize(@amount, @credit_card)
    assert_success response
    assert_equal 'Succeeded!', response.message
    assert_equal 'Authorization', response.params['transaction_type']
    assert response.authorization

    assert capture_response = @gateway.capture(@amount, response.authorization)
    assert_success capture_response
    assert_equal 'Succeeded!', capture_response.message
  end

  def test_successful_authorize_with_card_and_address
    options = {
      :email => 'joebob@example.com',
      :billing_address => address,
    }

    assert response = @gateway.authorize(@amount, @credit_card, options)
    assert_success response
    assert_equal 'Succeeded!', response.message
    assert_equal 'Authorization', response.params['transaction_type']

    assert_equal 'joebob@example.com', response.params['payment_method_email']
    assert_equal '1234 My Street', response.params['payment_method_address1']
    assert_equal 'Apt 1', response.params['payment_method_address2']
    assert_equal 'Ottawa', response.params['payment_method_city']
    assert_equal 'ON', response.params['payment_method_state']
    assert_equal 'K1C2N6', response.params['payment_method_zip']
  end

  def test_failed_authorize_with_declined_credit_card
    assert response = @gateway.authorize(@amount, @declined_card)
    assert_failure response
    assert_equal 'Unable to process the authorize transaction.', response.message
  end

  def test_failed_authrorize_with_invalid_credit_card
    @credit_card.first_name = ' '
    assert response = @gateway.authorize(@amount, @credit_card)
    assert_failure response
    assert_equal "First name can't be blank", response.message
  end

  def test_successful_authorize_with_store
    assert response = @gateway.authorize(@amount, @credit_card, store: true)
    assert_success response
    assert_equal 'Succeeded!', response.message
    assert_equal 'Authorization', response.params['transaction_type']
    assert_equal 'retained', response.params['payment_method_storage_state']
    assert !response.params['payment_method_token'].blank?
  end

  def test_successful_store
    assert response = @gateway.store(@credit_card)
    assert_success response
    assert_equal 'Succeeded!', response.message
    assert_equal response.params['payment_method_token'], response.authorization
    assert_equal 'Longbob', response.params['payment_method_first_name']
    assert_equal 'true', response.params['retained']
  end

  def test_successful_store_simple_data
    assert response = @gateway.store(@credit_card, { :data => 'SomeData' })
    assert_success response
    assert_equal 'SomeData', response.params['payment_method_data']
  end

  def test_successful_store_nested_data
    options = {
      :data => {
        :first_attribute => { :sub_dude => 'ExcellentSubValue' },
        :second_attribute => 'AnotherValue'
      }
    }
    assert response = @gateway.store(@credit_card, options)
    assert_success response
    expected_data = { 'first_attribute' => { 'sub_dude'=>'ExcellentSubValue' }, 'second_attribute' =>'AnotherValue' }
    assert_equal expected_data, response.params['payment_method_data']
  end

  def test_successful_store_with_address
    options = {
      :email => 'joebob@example.com',
      :billing_address => address,
    }

    assert response = @gateway.store(@credit_card, options)
    assert_success response
    assert_equal 'joebob@example.com', response.params['payment_method_email']
    assert_equal '1234 My Street', response.params['payment_method_address1']
    assert_equal 'Apt 1', response.params['payment_method_address2']
    assert_equal 'Ottawa', response.params['payment_method_city']
    assert_equal 'ON', response.params['payment_method_state']
    assert_equal 'K1C2N6', response.params['payment_method_zip']
  end

  def test_failed_store
    assert response = @gateway.store(credit_card('5555555555554444', :last_name => '  '))
    assert_failure response
    assert_equal "Last name can't be blank", response.message
  end

  def test_unstore
    assert response = @gateway.store(@credit_card)
    assert_success response

    assert response = @gateway.unstore(response.authorization)
    assert_success response
    assert_equal 'Succeeded!', response.message
    assert_equal 'RedactPaymentMethod', response.params['transaction_type']
  end

  def test_successful_refund
    assert response = @gateway.purchase(@amount, @existing_payment_method)
    assert_success response

    assert refund = @gateway.refund(@amount, response.authorization)
    assert_success refund
    assert_equal 'Succeeded!', refund.message
  end

  def test_failed_refund
    assert response = @gateway.purchase(@amount, @existing_payment_method)
    assert_success response

    assert refund = @gateway.refund(44, response.authorization)
    assert_failure refund
    assert_equal 'Unable to process the credit transaction.', refund.message
  end

  def test_successful_void
    assert response = @gateway.purchase(@amount, @existing_payment_method)
    assert_success response

    assert response = @gateway.void(response.authorization)
    assert_success response
    assert_equal 'Succeeded!', response.message
  end

  def test_invalid_login
    gateway = SpreedlyCoreGateway.new(:login => 'Bogus', :password => 'MoreBogus', :gateway_token => 'EvenMoreBogus')

    assert response = gateway.purchase(@amount, @existing_payment_method)
    assert_failure response
    assert_match /Unable to authenticate/, response.message
  end
end
