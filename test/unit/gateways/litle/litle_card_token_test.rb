require 'test_helper'

class LitleCardTokenTest < Test::Unit::TestCase
  def setup
    @card_token = LitleGateway::LitleCardToken.new(
      :token              => '1234567890123456',
      :month              => 9,
      :year               => Time.now.year + 1,
      :brand              => 'visa',
      :verification_value => '123'
    )
  end

  def test_constructor_should_properly_assign_values
    assert_equal '1234567890123456', @card_token.token
    assert_equal 9, @card_token.month
    assert_equal Time.now.year + 1, @card_token.year
    assert_equal 'visa', @card_token.brand
    assert_equal 'VI', @card_token.type
    assert_equal '123', @card_token.verification_value
    assert_valid @card_token
  end

  def test_new_card_token_should_not_be_valid
    c = LitleGateway::LitleCardToken.new

    assert_not_valid c
    assert_false c.errors.empty?
  end

  def test_should_be_able_to_access_errors_indifferently
    @card_token.token = ''

    assert_not_valid @card_token
    assert @card_token.errors.on(:token)
    assert @card_token.errors.on('token')
  end

  def test_should_be_able_to_identify_invalid_tokens
    @card_token.token = nil
    assert_not_valid @card_token

    @card_token.token = '11112222333344ff'
    assert_not_valid @card_token
    assert @card_token.errors.on(:token)

    @card_token.token = '123456'
    assert_not_valid @card_token
    assert @card_token.errors.on(:token)

    @card_token.token = 'Q11ab222333344444'
    assert_not_valid @card_token
    assert @card_token.errors.on(:token)
  end

  def test_should_have_errors_with_invalid_card_brand_for_otherwise_correct_number
    @card_token.brand = 'larry'

    assert_not_valid @card_token
    assert @card_token.errors.on(:brand)
    assert !@card_token.errors.on(:token)
  end

  def test_should_have_blank_type_for_invalid_brand
    @card_token.brand = 'larry'

    assert_not_valid @card_token
    assert @card_token.errors.on(:brand)
    assert @card_token.type.blank?
  end

  def test_should_have_blank_type_with_blank_card_brand
    @card_token.brand = ''

    assert_valid @card_token
    assert @card_token.type.blank?
  end

  def test_should_require_a_valid_card_month
    @card_token.month = Time.now.utc.month
    @card_token.year  = Time.now.utc.year

    assert_valid @card_token
  end

  def test_should_not_be_valid_with_empty_month_and_valid_year
    @card_token.month = ''

    assert_not_valid @card_token
    assert_equal 'is not a valid month', @card_token.errors.on('month')
  end

  def test_should_not_be_valid_for_edge_month_cases
    @card_token.month = 13
    @card_token.year  = Time.now.year
    assert_not_valid @card_token
    assert @card_token.errors.on('month')

    @card_token.month = 0
    @card_token.year  = Time.now.year
    assert_not_valid @card_token
    assert @card_token.errors.on('month')
  end

  def test_should_be_invalid_with_valid_month_and_empty_year
    @card_token.year = ''
    assert_not_valid @card_token
    assert_equal 'is not a valid year', @card_token.errors.on('year')
  end

  def test_should_not_be_valid_for_edge_year_cases
    @card_token.year = 1987
    assert_not_valid @card_token
    assert @card_token.errors.on('year')

    @card_token.year = 1977
    assert_not_valid @card_token
    assert @card_token.errors.on('year')
  end

  def test_should_be_a_valid_future_year
    @card_token.year = Time.now.year + 1
    assert_valid @card_token
  end

  # The following is a regression for a bug that raised an exception when
  # a new credit card was validated
  def test_validate_new_card
    card_token = LitleGateway::LitleCardToken.new

    assert_nothing_raised do
      card_token.validate
    end
  end
end
