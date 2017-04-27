require 'test_helper'

class InContextPaypalExpressTest < Test::Unit::TestCase
  TEST_REDIRECT_URL = 'https://www.sandbox.paypal.com/checkoutnow?token=1234567890'
  LIVE_REDIRECT_URL = 'https://www.paypal.com/checkoutnow?token=1234567890'
  TEST_REDIRECT_URL_WITHOUT_REVIEW = 'https://www.sandbox.paypal.com/checkoutnow?token=1234567890&useraction=commit'
  LIVE_REDIRECT_URL_WITHOUT_REVIEW = 'https://www.paypal.com/checkoutnow?token=1234567890&useraction=commit'

  def setup
    @gateway = InContextPaypalExpressGateway.new(
      :login => 'cody',
      :password => 'test',
      :pem => 'PEM'
    )

    Base.mode = :test
  end

  def teardown
    Base.mode = :test
  end

  def test_live_redirect_url
    Base.mode = :production
    assert_equal LIVE_REDIRECT_URL, @gateway.redirect_url_for('1234567890')
  end

  def test_test_redirect_url
    assert_equal :test, Base.mode
    assert_equal TEST_REDIRECT_URL, @gateway.redirect_url_for('1234567890')
  end

  def test_live_redirect_url_without_review
    Base.mode = :production
    assert_equal LIVE_REDIRECT_URL_WITHOUT_REVIEW, @gateway.redirect_url_for('1234567890', review: false)
  end

  def test_test_redirect_url_without_review
    assert_equal :test, Base.mode
    assert_equal TEST_REDIRECT_URL_WITHOUT_REVIEW, @gateway.redirect_url_for('1234567890', review: false)
  end
end

