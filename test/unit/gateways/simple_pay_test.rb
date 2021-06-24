require 'test_helper'

class SimplePayTest < Test::Unit::TestCase
  def setup
    @gateway = SimplePayGateway.new({
      :merchantID  => 'PUBLICTESTHUF',
      :merchantKEY => 'FxDa5w314kLlNseq2sKuVwaqZshZT5d6',
      :redirectURL => 'https://127.0.0.1',
      :timeout     => 30,
      :returnRequest => true
    })

    @token = []
    @cardSecret = 'thesuperdupersecret'
    
    @credit_card = CreditCard.new(
      :number     => '4908366099900425',
      :month      => '10',
      :year       => '2021',
      :first_name => 'v2 AUTO',
      :last_name  => 'Tester',
      :verification_value  => '579'
    )

    @amount = 100

    @address = {
      :name =>  'myname',
      :company => 'company',
      :country => 'HU',
      :state => 'Budapest',
      :city => 'Budapest',
      :zip => '1111',
      :address => 'Address u.1',
      :address2 => 'Address u.2',
      :phone => '06301111111'
    }

    @options = {
      :amount => @amount,
      :email => 'email@email.hu',
      :address => @address
    }

    @options_for_auto = {
      :amount => @amount,
      :email => 'email@email.hu',
      :address => @address,
      :credit_card => @credit_card
    }

    @options_for_auth = {
      :orderRef => 'authorizationorderreffortesting',
      :amount => @amount,
      :email => 'email@email.hu',
      :address => @address
    }

    @options_with_secret = {
      :amount => @amount,
      :email => 'email@email.hu',
      :address => @address,
      :cardSecret => 'thesuperdupersecret'
    }

    @options_with_recurring = {
      :amount => @amount,
      :email => 'email@email.hu',
      :address => @address,
      :recurring => {
        :times => 3,
        :until => "2030-12-01T18:00:00+02:00",
        :maxAmount => 2000
      }
    }

    @fail_options = {
      :email => 'email@email.hu'
    }

  end

  def test_successful_purchase
    #NOT SURE
    #@gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@options)
    assert_success response

    assert_match response.message['paymentUrl'], !nil
    assert response.test?
  end

  def test_successful_purchase_with_secret
    response = @gateway.purchase(@options_with_secret)
    assert_success response

    assert_match response.message.has_key?('paymentUrl'), true
    assert response.test?
  end

  def test_successful_recurring_purchase
    response = @gateway.purchase(@options_with_recurring)
    assert_success response

    assert_match response.message.has_key?('tokens'), true
    assert response.test?
    
    @token = JSON[response]['tokens']
    
    options_with_token = @options
    options_with_token[:token] = @token[0]
    options_with_token[:threeDSReqAuthMethod ] = '02'
    options_with_token[:type ] = 'MIT'

    response = @gateway.dorecurring(options_with_token)
    assert_success response
  end

  def test_failed_purchase
    response = @gateway.purchase(@fail_options)
    assert_failure response
  end

  def test_successful_authorize
    response = @gateway.authorize(@options_for_auth)
    assert_success response

    assert_match response.message.has_key?('paymentUrl'), true
    assert response.test?
  end

  #TODO OTP ERROR
  # def test_failed_authorize
  #   response = @gateway.authorize(@fail_options)
  #   assert_failure response
  # end

  # def test_successful_capture
  #   response = @gateway.capture({
  #     :orderRef => 'authorizationorderreffortesting',
  #     :originalTotal => @amount,
  #     :approveTotal => @amount / 2
  #   })
  #   assert_success response
  # end

  # def test_failed_capture
  #   response = @gateway.capture({
  #     :originalTotal => @amount,
  #     :approveTotal => @amount
  #   })
  #   assert_failure response
  # end

  # def test_successful_refund
  #   response = @gateway.refund({
  #     :orderRef => 'authorizationorderreffortesting',
  #     :refundTotal  => @amount / 2
  #   })
  #   assert_success response
  # end

  # def test_failed_refund
  #   response = @gateway.refund({
  #     :refundTotal  => @amount
  #   })
  #   assert_failure response
  # end
  #TODO OTP ERROR
  
  def test_succesfull_auto
    response = @gateway.auto(@options_for_auto)
    assert_success response
  end

  def test_unsuccesfull_auto
    response = @gateway.auto(@fail_options)
    assert_failure response
  end

  def test_unsuccesfull_dorecurring
    response = @gateway.dorecurring(@fail_options)
    assert_failure response
  end

  private

  def pre_scrubbed
    '
      Run the remote tests for this gateway, and then put the contents of transcript.log here.
    '
  end

  def post_scrubbed
    '
      Put the scrubbed contents of transcript.log here after implementing your scrubbing function.
      Things to scrub:
        - Credit card number
        - CVV
        - Sensitive authentication details
    '
  end

  def successful_purchase_response
    %(
      Easy to capture by setting the DEBUG_ACTIVE_MERCHANT environment variable
      to "true" when running remote tests:

      $ DEBUG_ACTIVE_MERCHANT=true ruby -Itest \
        test/remote/gateways/remote_simple_pay_test.rb \
        -n test_successful_purchase
    )
  end

  def failed_purchase_response; end

  def successful_authorize_response; end

  def failed_authorize_response; end

  def successful_capture_response; end

  def failed_capture_response; end

  def successful_refund_response; end

  def failed_refund_response; end

  def successful_void_response; end

  def failed_void_response; end
end
