require 'test_helper'

class LiqpayHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @options = { :service => :liqpay,
                 :secret => @key,
                 :amount => 157.0 }
    @form_fields = { :merchant_id => 'i15520',
                     :secret => '3HSi',
                     :pay_way => 'card',
                     :currency => 'RUR',
                     :order_id => '12',
                     :description => 'Test payment',
                     :default_phone => '+71231212123',
                     :server_url => 'http://t/liqpay/server_url?&',
                     :result_url => 'http://t/liqpay/result_url?&' }

    @helper = Liqpay::Helper.new(@options, nil)
  end

  def test_form_fields
    @helper.payment_service_for(44, @username, @form_options) do |service|
      @form_fields.each do |key, value|
        service.add_field(key, value)
      end
    end

    fields = @helper.form_fields

    assert fields['operation_xml'].present?
    assert fields['signature'].present?
  end
end
