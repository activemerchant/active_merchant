require File.dirname(__FILE__) + '/../test_helper'

class CCVResultTest < Test::Unit::TestCase
  def test_nil_data
    result = CCVResult.new(nil)
    assert_nil result.code
    assert_nil result.message
    assert_nil result.match
    assert_false result.failure?
  end
  
  def test_blank_data
    result = CCVResult.new('')
    assert_nil result.code
    assert_nil result.message
    assert_nil result.match
    assert_false result.failure?
  end
  
  def test_successful_match
    result = CCVResult.new('M')
    assert_equal 'M', result.code
    assert_equal CCVResult::CODES['M'], result.message
    assert_equal :match, result.match
    assert_false result.failure?
  end
  
  def test_failed_match
    result = CCVResult.new('N')
    assert_equal 'N', result.code
    assert_equal CCVResult::CODES['N'], result.message
    assert_equal :no_match, result.match
    assert result.failure?
  end
  
  def test_to_hash
    result = CCVResult.new('M').to_hash
    assert_equal 'M', result['code']
    assert_equal CCVResult::CODES['M'], result['message']
    assert_equal 'match', result['match']
  end
end