require 'test_helper'

class AuthorizeNetXmlTest < Test::Unit::TestCase
  def shipping_address(options = {})
    {
        :ship_to_first_name => 'Sammy',
        :ship_to_last_name => 'Baugh',
        :ship_to_company => 'Washington Redskins',
        :ship_to_address => '1 Redskin Drive',
        :ship_to_city     => 'Ottawa',
        :ship_to_state    => 'ON',
        :ship_to_zip      => 'K1C2N6',
        :ship_to_country  => 'CA',
        :phone    => '(555)555-5555',
        :fax      => '(555)555-6666'
    }.update(options)
  end

  def setup
    Base.mode = :test


    @gateway = ActiveMerchant::Billing::AuthorizeNetXmlGateway.new(fixtures(:authorize_net))
    @gateway.duplicate_window = 0

    @amount = 100
    @credit_card = credit_card('4242424242424242')
    @check = check
    @options = {
        :gateway => :sandbox,
        :order_id => generate_unique_id,
        :billing_address => address,
        :shipping_address => shipping_address,
        :email_address => 'sbaugh@gmail.com',
        :fax => '(801)555-5546',
        :description => 'Store purchase'
    }

    @recurring_options = {
        :amount => 100,
        :subscription_name => 'Test Subscription 1',
        :credit_card => @credit_card,
        :billing_address => address.merge(:first_name => 'Jim', :last_name => 'Smith'),
        :interval => {
            :length => 1,
            :unit => :months
        },
        :duration => {
            :start_date => Date.today,
            :occurrences => 1
        }
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert response.test?
    assert_equal 'This transaction has been approved.', response.message
    assert response.authorization
  end

  def test_card_present_purchase
    @credit_card.track_data = '%B378282246310005^LONGSON/LONGBOB^1705101130504392?'
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert response.test?
    assert_equal 'This transaction has been approved.', response.message
    assert response.authorization
  end

  def test_successful_echeck_purchase
    assert response = @gateway.purchase(@amount, @check, @options)
    assert_success response
    assert response.test?
    assert_equal 'This transaction has been approved.', response.message
    assert response.authorization
  end

  def test_expired_credit_card
    @credit_card.year = 2004
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
    assert_equal 'The credit card has expired.', response.message
  end

  def test_successful_authorization
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'This transaction has been approved.', response.message
    assert response.authorization
  end

  def test_successfule_echeck_authorization
    assert response = @gateway.authorize(@amount, @check, @options)
    assert_success response
    assert_equal 'This transaction has been approved.', response.message
    assert response.authorization
  end

  def test_authorization_and_capture
    assert authorization = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorization

    assert capture = @gateway.capture(@amount, authorization.params['transaction_id'])
    assert_success capture
    assert_equal 'This transaction has been approved.', capture.message
  end

  def test_card_present_authorize_and_capture
    @credit_card.track_data = ';4111111111111111=1803101000020000831?'
    assert authorization = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorization

    assert capture = @gateway.capture(@amount, authorization.params['transaction_id'])
    assert_success capture
    assert_equal 'This transaction has been approved.', capture.message
  end

  def test_authorization_and_void
    assert authorization = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorization

    assert void = @gateway.void(authorization.params['transaction_id'])
    assert_success void
    assert_equal 'This transaction has been approved.', void.message
  end

  def test_call_to_purchase_and_refund
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.params['transaction_id'], @credit_card)
    assert_failure refund
    assert_equal 'The referenced transaction does not meet the criteria for issuing a credit.', refund.message
  end

  def test_bad_login
    gateway = AuthorizeNetGateway.new(
      :login => 'X',
      :password => 'Y'
    )

    assert response = gateway.purchase(@amount, @credit_card)

    assert_equal Response, response.class
    assert_equal ["action",
                  "authorization_code",
                  "avs_result_code",
                  "card_code",
                  "cardholder_authentication_code",
                  "response_code",
                  "response_reason_code",
                  "response_reason_text",
                  "transaction_id"], response.params.keys.sort

    assert_match(/The merchant login ID or password is invalid/, response.message)

    assert_equal false, response.success?
  end

  def test_using_test_request
    gateway = AuthorizeNetGateway.new(
      :login => 'X',
      :password => 'Y'
    )

    assert response = gateway.purchase(@amount, @credit_card)

    assert_equal Response, response.class
    assert_equal ["action",
                  "authorization_code",
                  "avs_result_code",
                  "card_code",
                  "cardholder_authentication_code",
                  "response_code",
                  "response_reason_code",
                  "response_reason_text",
                  "transaction_id"], response.params.keys.sort

    assert_match(/The merchant login ID or password is invalid/, response.message)

    assert_equal false, response.success?
  end

  def test_successful_recurring
    assert response = @gateway.recurring(@amount, @credit_card, @recurring_options)
    assert_success response
    assert response.test?

    subscription_id = response.authorization

    assert response = @gateway.update_recurring(:subscription_id => subscription_id, :amount => @amount * 2)
    assert_success response

    assert response = @gateway.status_recurring(subscription_id)
    assert_success response

    assert response = @gateway.cancel_recurring(subscription_id)
    assert_success response
  end

  def test_recurring_should_fail_expired_credit_card
    @credit_card.year = 2004
    assert response = @gateway.recurring(@amount, @credit_card, @recurring_options)
    assert_failure response
    assert response.test?
    assert_equal 'E00018', response.params['code']
  end

=begin
  I don't see any mapping to a solution id in the SDK
  def test_successful_purchase_with_solution_id
    ActiveMerchant::Billing::AuthorizeNetXmlGateway.application_id = 'A1000000'
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert response.test?
    assert_equal 'This transaction has been approved.', response.message
    assert response.authorization
  ensure
    ActiveMerchant::Billing::AuthorizeXmlNetGateway.application_id = nil
  end

=begin

  THE CURRENCY CODE IS NOT CURRENTLY SUPPORTED BY THE AUTHORIZE.NET API

  def test_bad_currency
    @options[:currency] = "XYZ"
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'The supplied currency code is either invalid, not supported, not allowed for this merchant or doesn\'t have an exchange rate', response.message
  end

  def test_usd_currency
    @options[:currency] = "USD"
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert response.authorization
  end
=end

end
