require 'test/unit'
require File.dirname(__FILE__) + '/../test_helper'

######################################################################
#
# To run these tests, set the variables at the top of the class
# definition.
#
# Note that NetRegistry does not provide any sort of test
# server/account, so you'll probably want to refund any uncredited
# purchases through the NetRegistry console at www.netregistry.com .
# All purchases made in these tests are $1, so hopefully you won't be
# sent broke if you forget...
#
######################################################################

class NetRegistryTest < Test::Unit::TestCase
  #
  # Provide valid data here to run the tests.
  #
  # LOG_FILE_NAME may be nil, or a filename to write messages sent to
  # and received from the gateway
  #

  LOG_FILE_NAME = nil
  VALID_CARD_DETAILS = {
    :number => '4111111111111111',
    :month => 12,
    :year => 2010,
    :first_name => 'Longbob',
    :last_name => 'Longsen',
    :type => :visa,
  }

  def setup
    if LOG_FILE_NAME
      @log_file = open(LOG_FILE_NAME, 'a')
      @logger = Logger.new(@log_file)
    end

    @gateway = NetRegistryGateway.new(fixtures(:net_registry))

    @valid_creditcard = CreditCard.new(VALID_CARD_DETAILS)
    @invalid_creditcard = CreditCard.new(
      VALID_CARD_DETAILS.merge(:type => :visa, :number => '4111111111111111')
    )
    @expired_creditcard = CreditCard.new(
      VALID_CARD_DETAILS.merge(:year => 2000)
    )
    @invalid_month_creditcard = CreditCard.new(
      VALID_CARD_DETAILS.merge(:month => 13)
    )
  end

  def teardown
    @log_file.close if @log_file
  end

  def test_successful_purchase_and_credit
    response = @gateway.purchase(100, @valid_creditcard)
    assert_equal 'approved', response.params['status']
    assert_success response
    assert_match(/\A\d{16}\z/, response.authorization)

    response = @gateway.credit(100, response.authorization)
    assert_equal 'approved', response.params['status']
    assert_success response
  end

  #
  # # authorize and #capture haven't been tested because the author's
  # account hasn't been setup to support these methods (see the
  # documentation for the NetRegistry gateway class).  There is no
  # mention of a #void transaction in NetRegistry's documentation,
  # either.
  #
  if ENV['TEST_AUTHORIZE_AND_CAPTURE']
    def test_successful_authorization_and_capture
      response = @gateway.authorize(100, @valid_creditcard)
      assert_success response
      assert_equal 'approved', response.params['status']
      assert_match(/\A\d{6}\z/, response.authorization)

      response = @gateway.capture(100,
                                  response.authorization,
                                  :credit_card => @valid_creditcard)
      assert_success response
      assert_equal 'approved', response.params['status']
    end
  end

  def test_purchase_with_invalid_credit_card
    response = @gateway.purchase(100, @invalid_creditcard)
    assert_equal 'declined', response.params['status']
    assert_equal 'INVALID CARD', response.message
    assert_failure response
  end

  def test_purchase_with_expired_credit_card
    response = @gateway.purchase(100, @expired_creditcard)
    assert_equal 'failed', response.params['status']
    assert_equal 'CARD EXPIRED', response.message
    assert_failure response
  end

  def test_purchase_with_invalid_month
    response = @gateway.purchase(100, @invalid_month_creditcard)
    assert_equal 'failed', response.params['status']
    assert_equal 'Invalid month', response.message
    assert_failure response
  end

  def test_bad_login
    @gateway = NetRegistryGateway.new(:login    => 'bad-login',
                                      :password => 'bad-login')
    response = @gateway.purchase(100, @valid_creditcard)
    assert_equal 'failed', response.params['status']
    assert_failure response
  end
end
