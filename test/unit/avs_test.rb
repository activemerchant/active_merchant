require File.dirname(__FILE__) + '/../test_helper'

class AVSTest < Test::Unit::TestCase
  def test_no_match
    result = AVS::Result.new('N')
    assert_equal 'N', result.code
    assert_equal AVS::CODES['N'], result.message
    assert_equal :none, result.match_type
    assert result.failure?
  end
  
  def test_partial_match
    result = AVS::Result.new('A')
    assert_equal 'A', result.code
    assert_equal AVS::CODES['A'], result.message
    assert_equal :partial, result.match_type
    assert result.failure?
  end
  
  def test_full_match
    result = AVS::Result.new('X')
    assert_equal 'X', result.code
    assert_equal AVS::CODES['X'], result.message
    assert_equal :full, result.match_type
    assert_false result.failure?
  end
  
  def test_nil_data
    result = AVS::Result.new(nil)
    assert_nil result.code
    assert_nil result.message
    assert_nil result.match_type
    assert_false result.failure?
  end
  
  def test_empty_data
    result = AVS::Result.new(nil)
    assert_nil result.code
    assert_nil result.message
    assert_nil result.match_type
    assert_false result.failure?
  end
  
  def test_to_hash
    avs_data = AVS::Result.new('X').to_hash
    assert_equal 'X', avs_data['code']
    assert_equal AVS::CODES['X'], avs_data['message']
    assert_equal 'full', avs_data['match_type']
  end
end