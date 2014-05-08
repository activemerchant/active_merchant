require 'test_helper'

class KlarnaModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def test_notification_method
    Klarna::Notification.expects(:new).with('post_body', authorization_header: 'auth header')
    Klarna.notification('post_body', authorization_header: 'auth header')
  end

  def test_sign_without_discount_rate
    fields = {
      'purchase_country' => 'SE',
      'purchase_currency' => 'SEK',
      'locale' => 'sv-se',
      'merchant_id' => '1860',
      'merchant_terms_uri' => 'http://some-webstore.se?URI=tc',
      'merchant_checkout_uri' => 'http://some-webstore.se?URI=checkout',
      'merchant_base_uri' => 'http://some-webstore.se?URI=home',
      'merchant_confirmation_uri' => 'http://some-webstore.se?URI=confirmation'
    }

    cart_items = [{:type => 'physical',
                  :reference => '12345',
                  :quantity => '1',
                  :unit_price => '10000'}]

    shared_secret = 'example-shared-secret'

    calculated_digest = "AB4kuszp2Y4laIP4pfbHTJTPAsR7gFRxh4ml5LEDZxg="
    assert_equal calculated_digest, Klarna.sign(fields, cart_items, shared_secret)
  end

  def test_sign
    expected = Digest::SHA256.base64digest('abcdefopq')
    assert_equal expected, Klarna.digest('abcdef', 'opq')
  end
end
