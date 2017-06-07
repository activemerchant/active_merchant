require 'test_helper'

class WebPay3HelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def test_form_fields
    amount = 12345
    currency = 'USD'
    key = fixtures(:web_pay3)[:key]
    merchant_token = fixtures(:web_pay3)[:merchant_token]
    transaction_type = fixtures(:web_pay3)[:transaction_type]
    language = fixtures(:web_pay3)[:language]
    order_number = '12345_order_number'

    options = { credential2: key,
                amount: amount,
                currency: currency,
                transaction_type: transaction_type,
                credential3: language
              }

    address = { name: 'John Doe',
                address1: 'Street 15',
                city: 'Old Town',
                zip: '123456',
                country: 'Azeroth',
                phone: '00-123 456-7',
                email: 'email@email.com'
              }

    @helper = WebPay3::Helper.new order_number, merchant_token, options
    @helper.address address
    @helper.add_field('order_info', 'order_info')

    fields = @helper.form_fields

    # merchant
    assert_field 'merchant_token', merchant_token
    assert_field 'transaction_type', transaction_type
    assert_field 'language', language

    # order
    assert_field 'order_number', order_number
    assert_field 'order_info', 'order_info'

    # buyer
    assert_field 'ch_full_name', 'John Doe'
    assert_field 'ch_address', 'Street 15'
    assert_field 'ch_city', 'Old Town'
    assert_field 'ch_zip', '123456'
    assert_field 'ch_country', 'Azeroth'
    assert_field 'ch_phone', '00-123 456-7'
    assert_field 'ch_email', 'email@email.com'

    # digest
    assert_field 'digest', Digest::SHA1.hexdigest("#{key}#{fields['order_number']}#{fields['amount']}#{fields['currency']}")
  end
end
