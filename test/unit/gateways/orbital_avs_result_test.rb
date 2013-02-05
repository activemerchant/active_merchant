require 'test_helper'

class OrbitalAVSResultTest < Test::Unit::TestCase
  def test_no_match
    check_match_results('G', 'N', 'N')
  end

  def test_only_street_match
    check_match_results('F', 'Y', 'N')
  end

  def test_only_postal_match
    check_match_results('A', 'N', 'Y')
  end

  def test_nil_data
    result = ActiveMerchant::Billing::OrbitalGateway::AVSResult.new(nil)
    assert_nil result.code
    assert_nil result.message
  end

  def test_empty_data
    result = ActiveMerchant::Billing::OrbitalGateway::AVSResult.new('')
    assert_nil result.code
    assert_nil result.message
  end

  def test_response_with_orbital_avs
    response = Response.new(true, 'message', {}, :avs_result => OrbitalGateway::AVSResult.new('A'))

    assert_equal 'A', response.avs_result['code']
  end

  def test_response_with_orbital_avs_nil
    response = Response.new(true, 'message', {}, :avs_result => OrbitalGateway::AVSResult.new(nil))

    assert response.avs_result.has_key?('code')
  end

  # Helper functions

  def check_match_results(code, street_match, postal_match)
    result = ActiveMerchant::Billing::OrbitalGateway::AVSResult.new(code)
    assert_equal code, result.code
    assert_equal street_match, result.street_match
    assert_equal postal_match, result.postal_match
    assert_equal ActiveMerchant::Billing::OrbitalGateway::AVSResult.messages[code], result.message

    avs_data = result.to_hash
    assert_equal code, avs_data['code']
    assert_equal ActiveMerchant::Billing::OrbitalGateway::AVSResult.messages[code], avs_data['message']
  end
end
