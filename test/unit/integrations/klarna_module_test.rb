require 'test_helper'

class Hash
  def add_stringified_keys!
    keys.each {|key| self[key.to_s] = self[key] }
  end
end

class KlarnaModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def test_notification_method
    assert_instance_of Klarna::Notification, Klarna.notification('name=cody')
  end

  def test_sign
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

    cart_items = [CartItemWithDiscountRate.new('physical', '12345', '1', '10000', '1000')]

    shared_secret = 'example-shared-secret'

    calculated_digest = "eEvBSNj7drZoBk6JX83ioAkpLSsYmHSDZWH2jkHvY+g="
    assert_equal calculated_digest, Klarna.sign(fields, cart_items, shared_secret)
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
                   :quantity => ''}]

    cart_items = [CartItemWithoutDiscountRate.new('physical', '12345', '1', '10000')]

    item = cart_items.first.to_h

    item.add_stringified_keys!

    cart_items = [item]

    shared_secret = 'example-shared-secret'

    calculated_digest = "U7HXXlQ6J1Spybv5QA/jZrUP1ud5pWoNxAgYczpQifg="
    assert_equal calculated_digest, Klarna.sign(fields, cart_items, shared_secret)
  end

  CartItemWithoutDiscountRate = Struct.new(:type, :reference, :quantity, :unit_price)
  CartItemWithDiscountRate = Struct.new(:type, :reference, :quantity, :unit_price, :discount_rate)
end
