require 'test_helper'

class KlarnaNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @options = {:authorization_header => authorization_header, :credential2 => 'Example shared secret', :query_string => 'order=123'}
    @klarna = Klarna::Notification.new(request_body, @options)
  end

  def test_accessors
    assert @klarna.complete?
    assert_equal "Completed", @klarna.status
    assert_equal "14565D2494490B11C39E7220000", @klarna.transaction_id
    assert_equal "123", @klarna.item_id
    assert_equal "1110.98", @klarna.gross
    assert_equal "SEK", @klarna.currency
    assert_equal "2014-04-15T16:38:04+02:00", @klarna.received_at
    assert_equal "checkout-se@testdrive.klarna.com", @klarna.payer_email
    assert_equal "checkout-se@testdrive.klarna.com", @klarna.receiver_email
  end

  def test_x2ness_of_gross_amount
    @klarna.stubs(gross_cents: 100)

    assert_equal '1.00', @klarna.gross
  end

  def test_compositions
    assert_equal Money.new(111098, 'SEK'), @klarna.amount
  end

  def test_acknowledge
    @klarna = Klarna::Notification.new(request_body, @options)

    assert @klarna.acknowledge
  end

  def test_invalid_acknowledgement
    @options[:authorization_header] = 'not a valid verification header'
    @klarna = Klarna::Notification.new(request_body, @options)

    assert !@klarna.acknowledge
  end

  private

  def authorization_header
    'Klarna ZNOFMRaomg8AorjJBuWiTtx/oawCQneRvZlzwE2ypac='
  end
  
  def request_body
    "{\"id\":\"14565D2494490B11C39E7220000\",\"purchase_country\":\"se\",\"purchase_currency\":\"sek\",\"locale\":\"sv-se\",\"status\":\"checkout_complete\",\"reference\":\"14565D2494490B11C39E7220000\",\"reservation\":\"2348456980\",\"started_at\":\"2014-04-15T16:37:31+02:00\",\"completed_at\":\"2014-04-15T16:38:04+02:00\",\"last_modified_at\":\"2014-04-15T16:38:04+02:00\",\"expires_at\":\"2014-04-29T16:38:04+02:00\",\"cart\":{\"total_price_excluding_tax\":111098,\"total_tax_amount\":0,\"total_price_including_tax\":111098,\"items\":[{\"reference\":\"4\",\"name\":\"Torp Inc Switchable clear-thinking strategy Froopy\",\"quantity\":1,\"unit_price\":38099,\"tax_rate\":0,\"discount_rate\":0,\"type\":\"physical\",\"total_price_including_tax\":38099,\"total_price_excluding_tax\":38099,\"total_tax_amount\":0},{\"reference\":\"1\",\"name\":\"Kshlerin-Ratke Polarised static system engine Red\",\"quantity\":1,\"unit_price\":70499,\"tax_rate\":0,\"discount_rate\":0,\"type\":\"physical\",\"total_price_including_tax\":70499,\"total_price_excluding_tax\":70499,\"total_tax_amount\":0},{\"reference\":\"\",\"name\":\"International Shipping\",\"quantity\":1,\"unit_price\":2500,\"tax_rate\":0,\"discount_rate\":0,\"type\":\"shipping_fee\",\"total_price_including_tax\":2500,\"total_price_excluding_tax\":2500,\"total_tax_amount\":0},{\"reference\":\"\",\"name\":\"Discount amount\",\"quantity\":1,\"unit_price\":0,\"tax_rate\":0,\"discount_rate\":0,\"type\":\"discount\",\"total_price_including_tax\":0,\"total_price_excluding_tax\":0,\"total_tax_amount\":0}]},\"customer\":{\"type\":\"person\"},\"shipping_address\":{\"given_name\":\"Testperson-se\",\"family_name\":\"Approved\",\"street_address\":\"St\xC3\xA5rgatan 1\",\"postal_code\":\"12345\",\"city\":\"ANKEBORG\",\"country\":\"se\",\"email\":\"checkout-se@testdrive.klarna.com\",\"phone\":\"070 111 11 11\"},\"billing_address\":{\"given_name\":\"Testperson-se\",\"family_name\":\"Approved\",\"street_address\":\"St\xC3\xA5rgatan 1\",\"postal_code\":\"12345\",\"city\":\"ANKEBORG\",\"country\":\"se\",\"email\":\"checkout-se@testdrive.klarna.com\",\"phone\":\"070 111 11 11\"},\"gui\":{\"layout\":\"mobile\",\"snippet\":\"\\u003Cdiv id=\\\"klarna-checkout-container\\\" style=\\\"overflow-x: hidden;\\\"\\u003E\\u003Cscript type=\\\"text/javascript\\\"\\u003E/* \\u003C![CDATA[ */(function(w,k,i,d,u,n,c){w[k]=w[k]||function(){(w[k].q=w[k].q||[]).push(arguments)};w[k].config={container:w.document.getElementById(i),TESTDRIVE:true,ORDER_URL:'https://checkout.testdrive.klarna.com/checkout/orders/14565D2494490B11C39E7220000',AUTH_HEADER:'KlarnaCheckout MZgHnXfVkfa69iMgov2Q',LAYOUT:'mobile',LOCALE:'sv-se',ORDER_STATUS:'checkout_complete',MERCHANT_TAC_URI:'http://shop1.myshopify.io:3000',MERCHANT_TAC_TITLE:'ShopifyTest',MERCHANT_NAME:'ShopifyTest',GUI_OPTIONS:[],ALLOW_SEPARATE_SHIPPING_ADDRESS:false,PURCHASE_COUNTRY:'swe',PURCHASE_CURRENCY:'sek',BOOTSTRAP_SRC:u};n=d.createElement('script');c=d.getElementById(i);n.async=!0;n.src=u;c.insertBefore(n,c.firstChild);})(this,'_klarnaCheckout','klarna-checkout-container',document,'https://checkout.testdrive.klarna.com/140218-2318fcb/checkout.bootstrap.js');/* ]]\\u003E */\\u003C/script\\u003E\\u003Cnoscript\\u003EPlease \\u003Ca href=\\\"http://enable-javascript.com\\\"\\u003Eenable JavaScript\\u003C/a\\u003E.\\u003C/noscript\\u003E\\u003C/div\\u003E\"},\"options\":{\"allow_separate_shipping_address\":false},\"merchant\":{\"id\":\"1860\",\"terms_uri\":\"http://shop1.myshopify.io:3000\",\"checkout_uri\":\"https://hpp-staging-eu.herokuapp.com/1860/order/14565D2494490B11C39E7220000/checkout?test=1\",\"confirmation_uri\":\"https://hpp-staging-eu.herokuapp.com/1860/order/14565D2494490B11C39E7220000/confirmation?test=1\",\"push_uri\":\"https://hpp-staging-eu.herokuapp.com/1860/order/14565D2494490B11C39E7220000/notification?uri=http://733d4f4a.ngrok.com/services/ping/notify_integration/klarna/1\\u0026test=1\"}}"
  end
end
