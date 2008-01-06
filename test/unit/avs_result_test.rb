require File.dirname(__FILE__) + '/../test_helper'

class AVSResultTest < Test::Unit::TestCase
  def test_no_match
    result = AVSResult.new('N')
    assert_equal 'N', result.code
    assert_equal AVSResult::CODES['N'], result.message
    assert_equal :none, result.match_type
    assert result.failure?
  end
  
  def test_partial_match
    result = AVSResult.new('A')
    assert_equal 'A', result.code
    assert_equal AVSResult::CODES['A'], result.message
    assert_equal :partial, result.match_type
    assert result.failure?
  end
  
  def test_full_match
    result = AVSResult.new('X')
    assert_equal 'X', result.code
    assert_equal AVSResult::CODES['X'], result.message
    assert_equal :full, result.match_type
    assert_false result.failure?
  end
  
  def test_nil_data
    result = AVSResult.new(nil)
    assert_nil result.code
    assert_nil result.message
    assert_nil result.match_type
    assert_false result.failure?
  end
  
  def test_empty_data
    result = AVSResult.new(nil)
    assert_nil result.code
    assert_nil result.message
    assert_nil result.match_type
    assert_false result.failure?
  end
  
  def test_to_hash
    avs_data = AVSResult.new('X').to_hash
    assert_equal 'X', avs_data['code']
    assert_equal AVSResult::CODES['X'], avs_data['message']
    assert_equal 'full', avs_data['match_type']
  end
end