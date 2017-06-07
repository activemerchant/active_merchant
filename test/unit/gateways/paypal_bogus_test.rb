require 'test_helper'

class PaypalBogusTest < Test::Unit::TestCase
  def setup
    @gateway = PaypalBogusGateway.new(
                 :login => 'bogus',
                 :password => 'bogus'
               )
    @return_url = "http://foo.com"
    @cancel_return_url = "http://foo.com"
  end

  def test_setup_authorization
    assert_raise(ArgumentError) { @gateway.setup_authorization 1000 }
    assert @gateway.setup_authorization(1000, { :cancel_return_url => @cancel_return_url, 
                                                :return_url => @return_url }).success?
  end

  def test_redirect_url_for
    assert @gateway.redirect_url_for '1'
  end

  def authorize
    assert_raise(ArgumentError) { @gateway.authorize 1000 }
    assert !@gateway.authorize(1000, { :token => '1', :payer_id => '42' }).success?
    assert @gateway.authorize(1000, { :token => '2', :payer_id => '42' }).success?
  end

end
