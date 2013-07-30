require 'test_helper'

class TwoCheckoutReturnTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def test_live_purchase
    r = TwoCheckout::Return.new(live_purchase, :credential2 => 'tango')
    assert !r.test?
    assert r.acknowledge
  end

  def test_demo_purchase
    r = TwoCheckout::Return.new(demo_purchase, :credential2 => 'tango')
    assert r.test?
    assert r.acknowledge
  end

  def test_return_accessors
    r = TwoCheckout::Return.new(live_purchase, :credential2 => 'tango')
    assert_equal "3860340141", r.transaction_id
    assert_equal "codyfauser@gmail.com", r.payer_email
    assert_equal "codyfauser@gmail.com", r.receiver_email
    assert_equal "32B492C4FB01C0EF60E3F7DBF092DE5E", r.security_key
    assert_equal "#1009", r.item_id
    assert_equal "USD", r.currency
  end

  def test_live_acknowledgement
    r = TwoCheckout::Return.new(live_purchase, :credential2 => 'tango')
    assert r.acknowledge
  end
  
  def test_demo_acknowledgement
    r = TwoCheckout::Return.new(demo_purchase, :credential2 => 'tango')
    assert r.acknowledge
  end
  
  private
  def live_purchase
    'sid=1232919&fixed=Y&key=32B492C4FB01C0EF60E3F7DBF092DE5E&state=ON&email=codyfauser%40gmail.com&street_address=138+Clarence+St.&city=Ottawa&cart_order_id=9&order_number=3860340141&merchant_order_id=%231009&country=CAN&ip_country=&cart_id=9&lang=en&pay_method=CC&total=118.30&phone=%28613%29555-5555+&credit_card_processed=Y&zip=K1N5P8&street_address2=Apartment+1&card_holder_name=Cody++Fauser'
  end
  
  def demo_purchase
    'sid=1232919&fixed=Y&key=C17C887BDCCD0499264FAE9F578CCA66&state=ON&email=codyfauser%40gmail.com&street_address=138+Clarence+St.&city=Ottawa&cart_order_id=9&order_number=3860340141&merchant_order_id=%231009&country=CAN&ip_country=&cart_id=9&lang=en&demo=Y&pay_method=CC&total=118.30&phone=%28613%29555-5555+&credit_card_processed=K&zip=K1N5P8&street_address2=Apartment+1&card_holder_name=Cody++Fauser'
  end
end