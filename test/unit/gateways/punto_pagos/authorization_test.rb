require 'test_helper'
require File.expand_path(File.dirname(__FILE__) + '/../../../../lib/active_merchant/billing/gateways/punto_pagos/authorization')

class PuntoPagosAuthorizationTest < Test::Unit::TestCase
  def setup
    @auth_class = ActiveMerchant::Billing::PuntoPagos::Authorization
    @authorization = @auth_class.new(key: 'k', secret: 's')
  end

  def test_failed_initialization_with_invalid_keys
    assert_raise_message('Invalid key') do
      @auth_class.new(key: '', secret: 's')
    end

    assert_raise_message('Invalid secret') do
      @auth_class.new(key: 'k', secret: nil)
    end
  end

  def test_successful_sign
    assert_equal('PP k:foLweXBORVOYonstrW1kd3TLcMk=', @authorization.sign("a", "b", "c"))
  end
end
