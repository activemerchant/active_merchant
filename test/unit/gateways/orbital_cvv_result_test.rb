require 'test_helper'

class OrbitalCVVResultTest < Test::Unit::TestCase
  def test_nil_data
    result = ActiveMerchant::Billing::OrbitalGateway::CVVResult.new(nil)
    assert_equal '', result.code
    assert_equal ActiveMerchant::Billing::OrbitalGateway::CVVResult.messages[''], result.message
  end

  def test_blank_data
    result = ActiveMerchant::Billing::OrbitalGateway::CVVResult.new('')
    assert_equal '', result.code
    assert_equal ActiveMerchant::Billing::OrbitalGateway::CVVResult.messages[''], result.message
  end

  def test_successful_match
    result = ActiveMerchant::Billing::OrbitalGateway::CVVResult.new('M')
    assert_equal 'M', result.code
    assert_equal ActiveMerchant::Billing::OrbitalGateway::CVVResult.messages['M'], result.message
  end

  def test_failed_match
    result = ActiveMerchant::Billing::OrbitalGateway::CVVResult.new('N')
    assert_equal 'N', result.code
    assert_equal ActiveMerchant::Billing::OrbitalGateway::CVVResult.messages['N'], result.message
  end

  def test_code_upcasing
    result = ActiveMerchant::Billing::OrbitalGateway::CVVResult.new('m')
    assert_equal 'M', result.code
  end

  def test_to_hash
    result = ActiveMerchant::Billing::OrbitalGateway::CVVResult.new('M').to_hash
    assert_equal 'M', result['code']
    assert_equal ActiveMerchant::Billing::OrbitalGateway::CVVResult.messages['M'], result['message']
  end
end
