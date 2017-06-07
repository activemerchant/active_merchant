require 'test_helper'

class MolpayReturnTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @secret = 'secretkey'
    @skey = Digest::MD5.hexdigest("10.00molpaytestorder-10.00#{@secret}")
    @molpay = Molpay::Return.new(query_data, :credential2 => @secret)
  end

  def test_success?
    assert @molpay.success?
  end

  def test_failed?
    molpay = Molpay::Return.new('', :credential2 => @secret)

    assert !molpay.success?
  end

  private

  def query_data
    "amount=10.00&orderid=order-10.00&appcode=auth123&tranID=12345&domain=molpaytest&status=00&currency=MYR&paydate=2014-04-04 10:00:00&channel=MB2u&skey=#{@skey}"
  end
end
