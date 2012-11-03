require 'test_helper'
require 'active_merchant/billing/gateways/orbital/orbital_avs_result'

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
    result = OrbitalAVSResult.new(nil)
    assert_nil result.code
    assert_nil result.message
  end
  
  def test_empty_data
    result = OrbitalAVSResult.new('')
    assert_nil result.code
    assert_nil result.message
  end

  # Helper functions
  
  def check_match_results(code, street_match, postal_match)
    result = OrbitalAVSResult.new(code)
    assert_equal code, result.code
    assert_equal street_match, result.street_match
    assert_equal postal_match, result.postal_match
    assert_equal OrbitalAVSResult.messages[code], result.message

    avs_data = result.to_hash
    assert_equal code, avs_data['code']
    assert_equal OrbitalAVSResult.messages[code], avs_data['message']
  end
end
