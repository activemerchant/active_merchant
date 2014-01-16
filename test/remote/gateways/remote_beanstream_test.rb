require 'test_helper'

# This test suite assumes that you have enabled username/password transaction validation in your Beanstream account.
# You will experience some test failures if username/password validation transaction validation is not enabled.
# Beanstream does not allow Payment Profiles to be deleted with their API. The accounts are 'closed', but have to be deleted manually.  Because of this, some of these tests will
# only work the first time you run them since the profile, if created again, becomes a duplicate.  There is a setting in order settings which, when unchecked will allow the tests to be run any number
# of times without needing the manual deletion step between test runs.  The setting is: Do not allow profile to be created with card data duplicated from an existing profile.
class RemoteBeanstreamTest < Test::Unit::TestCase

  def setup
    @gateway = BeanstreamGateway.new(fixtures(:beanstream))

    # Beanstream test cards. Cards require a CVV of 123, which is the default of the credit card helper
    @visa                = credit_card('4030000010001234')
    @declined_visa       = credit_card('4003050500040005')

    @mastercard          = credit_card('5100000010001004')
    @declined_mastercard = credit_card('5100000020002000')

    @amex                = credit_card('371100001000131', {:verification_value => 1234})
    @declined_amex       = credit_card('342400001000180')

    # Canadian EFT
    @check               = check(
                             :institution_number => '001',
                             :transit_number     => '26729'
                           )

    @amount = 1500

    @options = {
      :order_id => generate_unique_id,
      :billing_address => {
        :name => 'xiaobo zzz',
        :phone => '555-555-5555',
        :address1 => '1234 Levesque St.',
        :address2 => 'Apt B',
        :city => 'Montreal',
        :state => 'QC',
        :country => 'CA',
        :zip => 'H2C1X8'
      },
      :email => 'xiaobozzz@example.com',
      :subtotal => 800,
      :shipping => 100,
      :tax1 => 100,
      :tax2 => 100,
      :custom => 'reference one'
    }

    @recurring_options = @options.merge(
      :interval => { :unit => :months, :length => 1 },
      :occurences => 5)
  end

  def test_successful_visa_purchase
    assert response = @gateway.purchase(@amount, @visa, @options)
    assert_success response
    assert_false response.authorization.blank?
    assert_equal "Approved", response.message
  end

  def test_unsuccessful_visa_purchase
    assert response = @gateway.purchase(@amount, @declined_visa, @options)
    assert_failure response
    assert_equal 'DECLINE', response.message
  end

  def test_successful_mastercard_purchase
    assert response = @gateway.purchase(@amount, @mastercard, @options)
    assert_success response
    assert_false response.authorization.blank?
    assert_equal "Approved", response.message
  end

  def test_unsuccessful_mastercard_purchase
    assert response = @gateway.purchase(@amount, @declined_mastercard, @options)
    assert_failure response
    assert_equal 'DECLINE', response.message
  end

  def test_successful_amex_purchase
    assert response = @gateway.purchase(@amount, @amex, @options)
    assert_success response
    assert_false response.authorization.blank?
    assert_equal "Approved", response.message
  end

  def test_unsuccessful_amex_purchase
    assert response = @gateway.purchase(@amount, @declined_amex, @options)
    assert_failure response
    assert_equal 'DECLINE', response.message
  end

  def test_authorize_and_capture
    assert auth = @gateway.authorize(@amount, @visa, @options)
    assert_success auth
    assert_equal "Approved", auth.message
    assert_false auth.authorization.blank?

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_false capture.authorization.blank?
  end

  def test_failed_capture
    assert response = @gateway.capture(@amount, '')
    assert_failure response
    assert_no_match %r{You are not authorized}, response.message, "You need to enable username/password validation"
    assert_match %r{Missing or invalid adjustment id.}, response.message
  end

  def test_successful_purchase_and_void
    assert purchase = @gateway.purchase(@amount, @visa, @options)
    assert_success purchase

    assert void = @gateway.void(purchase.authorization)
    assert_success void
  end

  def test_successful_purchase_and_refund_and_void_refund
    assert purchase = @gateway.purchase(@amount, @visa, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success purchase

    assert void = @gateway.void(refund.authorization)
    assert_success void
  end

  def test_successful_check_purchase
    assert response = @gateway.purchase(@amount, @check, @options)
    assert_success response
    assert response.test?
    assert_false response.authorization.blank?
  end

  def test_successful_check_purchase_and_refund
    assert purchase = @gateway.purchase(@amount, @check, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success credit
  end

  def test_successful_recurring
    assert response = @gateway.recurring(@amount, @visa, @recurring_options)
    assert_success response
    assert response.test?
    assert_false response.authorization.blank?
  end

  def test_successful_update_recurring
    assert response = @gateway.recurring(@amount, @visa, @recurring_options)
    assert_success response
    assert response.test?
    assert_false response.authorization.blank?

    assert response = @gateway.update_recurring(@amount + 500, @visa, @recurring_options.merge(:account_id => response.params["rbAccountId"]))
    assert_success response
  end

  def test_successful_cancel_recurring
    assert response = @gateway.recurring(@amount, @visa, @recurring_options)
    assert_success response
    assert response.test?
    assert_false response.authorization.blank?

    assert response = @gateway.cancel_recurring(:account_id => response.params["rbAccountId"])
    assert_success response
  end

  def test_invalid_login
    gateway = BeanstreamGateway.new(
                :merchant_id => '',
                :login => '',
                :password => ''
              )
    assert response = gateway.purchase(@amount, @visa, @options)
    assert_failure response
    assert_equal 'Invalid merchant id (merchant_id = 0)', response.message
  end

  def test_successful_add_to_vault_with_store_method
    assert response = @gateway.store(@visa,@options)
    assert_equal 'Operation Successful', response.message
    assert_success response
    assert_not_nil response.params["customer_vault_id"]
  end

  def test_add_to_vault_with_custom_vault_id_with_store_method
    @options[:vault_id] = rand(100000)+10001
    assert response = @gateway.store(@visa, @options.dup)
    assert_equal 'Operation Successful', response.message
    assert_success response
    assert_equal @options[:vault_id], response.params["customer_vault_id"].to_i
  end

  def test_successful_add_to_vault_with_single_use_token
    assert response = @gateway.store(generate_single_use_token(@visa))
    assert_equal 'Operation Successful', response.message, response.inspect
    assert_success response
    assert_not_nil response.params["customer_vault_id"]
  end

  def test_update_vault
    test_add_to_vault_with_custom_vault_id_with_store_method
    assert response = @gateway.update(@options[:vault_id], @mastercard)
    assert_success response
    assert_equal 'Operation Successful', response.message
  end

  def test_update_vault_with_single_use_token
    test_add_to_vault_with_custom_vault_id_with_store_method
    assert response = @gateway.update(@options[:vault_id], generate_single_use_token(@mastercard))
    assert_success response
    assert_equal 'Operation Successful', response.message
  end

  def test_delete_from_vault
    test_add_to_vault_with_custom_vault_id_with_store_method
    assert response = @gateway.delete(@options[:vault_id])
    assert_success response
    assert_equal 'Operation Successful', response.message
  end

  def test_delete_from_vault_with_unstore_method
    test_add_to_vault_with_custom_vault_id_with_store_method
    assert response = @gateway.unstore(@options[:vault_id])
    assert_success response
    assert_equal 'Operation Successful', response.message
  end

  def test_successful_add_to_vault_and_use
    test_add_to_vault_with_custom_vault_id_with_store_method
    assert second_response = @gateway.purchase(@amount*2, @options[:vault_id], @options)
    assert_equal 'Approved', second_response.message
    assert second_response.success?
  end

  def test_unsuccessful_visa_with_vault
    test_add_to_vault_with_custom_vault_id_with_store_method
    assert response = @gateway.update(@options[:vault_id], @declined_visa)
    assert_success response

    assert second_response = @gateway.purchase(@amount*2, @options[:vault_id], @options)
    assert_equal 'DECLINE', second_response.message
  end

  def test_unsuccessful_closed_profile_charge
    test_delete_from_vault
    assert second_response = @gateway.purchase(@amount*2, @options[:vault_id], @options)
    assert_failure second_response
    assert_match %r{Invalid customer code\.}, second_response.message
  end

  private

  def generate_single_use_token(credit_card)
    uri = URI.parse('https://www.beanstream.com/scripts/tokenization/tokens')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    request = Net::HTTP::Post.new(uri.path)
    request.content_type = "application/json"
    request.body = {
      "number"       => credit_card.number,
      "expiry_month" => "01",
      "expiry_year"  => (Time.now.year + 1) % 100,
      "cvd"          => credit_card.verification_value,
    }.to_json

    response = http.request(request)
    JSON.parse(response.body)["token"]
  end
end
