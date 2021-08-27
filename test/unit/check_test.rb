require 'test_helper'

class CheckTest < Test::Unit::TestCase
  VALID_ABA     = '111000025'
  INVALID_ABA   = '999999999'
  MALFORMED_ABA = 'I like fish'
  VALID_CBA = '00194611'
  INVALID_NINE_DIGIT_CBA = '012345678'
  INVALID_SEVEN_DIGIT_ROUTING_NUMBER = '0123456'

  ACCOUNT_NUMBER = '123456789012'

  def test_validation
    assert_not_valid Check.new
  end

  def test_first_name_last_name
    check = Check.new(name: 'Fred Bloggs')
    assert_equal 'Fred', check.first_name
    assert_equal 'Bloggs', check.last_name
    assert_equal 'Fred Bloggs', check.name
  end

  def test_nil_name
    check = Check.new(name: nil)
    assert_nil check.first_name
    assert_nil check.last_name
    assert_equal '', check.name
  end

  def test_valid
    assert_valid Check.new(
      name: 'Fred Bloggs',
      routing_number: VALID_ABA,
      account_number: ACCOUNT_NUMBER,
      account_holder_type: 'personal',
      account_type: 'checking'
    )
  end

  def test_credit_card?
    assert !check.credit_card?
  end

  def test_invalid_routing_number
    errors = assert_not_valid Check.new(routing_number: INVALID_ABA)
    assert_equal ['is invalid'], errors[:routing_number]
  end

  def test_malformed_routing_number
    errors = assert_not_valid Check.new(routing_number: MALFORMED_ABA)
    assert_equal ['is invalid'], errors[:routing_number]
  end

  def test_account_holder_type
    c = Check.new
    c.account_holder_type = 'business'
    assert !c.validate[:account_holder_type]

    c.account_holder_type = 'personal'
    assert !c.validate[:account_holder_type]

    c.account_holder_type = 'pleasure'
    assert_equal ['must be personal or business'], c.validate[:account_holder_type]

    c.account_holder_type = nil
    assert !c.validate[:account_holder_type]
  end

  def test_account_type
    c = Check.new
    c.account_type = 'checking'
    assert !c.validate[:account_type]

    c.account_type = 'savings'
    assert !c.validate[:account_type]

    c.account_type = 'moo'
    assert_equal ['must be checking or savings'], c.validate[:account_type]

    c.account_type = nil
    assert !c.validate[:account_type]
  end

  def test_valid_canada_routing_number
    assert_valid Check.new(
      name: 'Tim Horton',
      routing_number: VALID_CBA,
      account_number: ACCOUNT_NUMBER,
      account_holder_type: 'personal',
      account_type: 'checking'
    )
  end

  def test_invalid_nine_digit_canada_routing_number
    errors = assert_not_valid Check.new(
      name: 'Tim Horton',
      routing_number: INVALID_NINE_DIGIT_CBA,
      account_number: ACCOUNT_NUMBER,
      account_holder_type: 'personal',
      account_type: 'checking'
    )

    assert_equal ['is invalid'], errors[:routing_number]
  end

  def test_invalid_routing_number_length
    errors = assert_not_valid Check.new(
      name: 'Routing Shortlength',
      routing_number: INVALID_SEVEN_DIGIT_ROUTING_NUMBER,
      account_number: ACCOUNT_NUMBER,
      account_holder_type: 'personal',
      account_type: 'checking'
    )

    assert_equal ['is invalid'], errors[:routing_number]
  end
end
