require 'test_helper'

class CreditCardMethodsTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::CreditCardMethods

  class CreditCard
    include ActiveMerchant::Billing::CreditCardMethods
  end

  def maestro_card_numbers
    %w[
      5000000000000000 5099999999999999 5600000000000000
      5899999999999999 6000000000000000 6999999999999999
      6761999999999999 6763000000000000 5038999999999999
    ]
  end

  def non_maestro_card_numbers
    %w[
      4999999999999999 5100000000000000 5599999999999999
      5900000000000000 5999999999999999 7000000000000000
    ]
  end

  def test_should_be_able_to_identify_valid_expiry_months
    assert_false valid_month?(-1)
    assert_false valid_month?(13)
    assert_false valid_month?(nil)
    assert_false valid_month?('')

    1.upto(12) { |m| assert valid_month?(m) }
  end

  def test_should_be_able_to_identify_valid_expiry_years
    assert_false valid_expiry_year?(-1)
    assert_false valid_expiry_year?(Time.now.year + 21)

    0.upto(20) { |n| assert valid_expiry_year?(Time.now.year + n) }
  end

  def test_should_be_able_to_identify_valid_start_years
    assert valid_start_year?(1988)
    assert valid_start_year?(2007)
    assert valid_start_year?(3000)

    assert_false valid_start_year?(1987)
  end

  def test_valid_start_year_can_handle_strings
    assert valid_start_year?("2009")
  end

  def test_valid_month_can_handle_strings
    assert valid_month?("1")
  end

  def test_valid_expiry_year_can_handle_strings
    year = Time.now.year + 1
    assert valid_expiry_year?(year.to_s)
  end

  def test_should_validate_card_verification_value
    assert valid_card_verification_value?(123, 'visa')
    assert valid_card_verification_value?('123', 'visa')
    assert valid_card_verification_value?(1234, 'american_express')
    assert valid_card_verification_value?('1234', 'american_express')
    assert_false valid_card_verification_value?(12, 'visa')
    assert_false valid_card_verification_value?(1234, 'visa')
    assert_false valid_card_verification_value?(123, 'american_express')
    assert_false valid_card_verification_value?(12345, 'american_express')
  end

  def test_should_be_able_to_identify_valid_issue_numbers
    assert valid_issue_number?(1)
    assert valid_issue_number?(10)
    assert valid_issue_number?('12')
    assert valid_issue_number?(0)

    assert_false valid_issue_number?(-1)
    assert_false valid_issue_number?(123)
    assert_false valid_issue_number?('CAT')
  end

  def test_should_ensure_brand_from_credit_card_class_is_not_frozen
    assert_false CreditCard.brand?('4242424242424242').frozen?
  end

  def test_should_be_dankort_card_brand
    assert_equal 'dankort', CreditCard.brand?('5019717010103742')
  end

  def test_should_detect_visa_dankort_as_visa
    assert_equal 'visa', CreditCard.brand?('4571100000000000')
  end

  def test_should_detect_electron_dk_as_visa
    assert_equal 'visa', CreditCard.brand?('4175001000000000')
  end

  def test_should_detect_diners_club
    assert_equal 'diners_club', CreditCard.brand?('36148010000000')
  end

  def test_should_detect_diners_club_dk
    assert_equal 'diners_club', CreditCard.brand?('30401000000000')
  end

  def test_should_detect_maestro_dk_as_maestro
    assert_equal 'maestro', CreditCard.brand?('6769271000000000')
  end

  def test_should_detect_maestro_cards
    assert_equal 'maestro', CreditCard.brand?('5020100000000000')

    maestro_card_numbers.each { |number| assert_equal 'maestro', CreditCard.brand?(number) }
    non_maestro_card_numbers.each { |number| assert_not_equal 'maestro', CreditCard.brand?(number) }
  end

  def test_should_detect_mastercard
    assert_equal 'master', CreditCard.brand?('6771890000000000')
    assert_equal 'master', CreditCard.brand?('5413031000000000')
  end

  def test_should_detect_forbrugsforeningen
    assert_equal 'forbrugsforeningen', CreditCard.brand?('6007221000000000')
  end

  def test_should_detect_laser_card
    # 16 digits
    assert_equal 'laser', CreditCard.brand?('6304985028090561')

    # 18 digits
    assert_equal 'laser', CreditCard.brand?('630498502809056151')

    # 19 digits
    assert_equal 'laser', CreditCard.brand?('6304985028090561515')

    # 17 digits
    assert_not_equal 'laser', CreditCard.brand?('63049850280905615')

    # 15 digits
    assert_not_equal 'laser', CreditCard.brand?('630498502809056')

    # Alternate format
    assert_equal 'laser', CreditCard.brand?('6706950000000000000')

    # Alternate format (16 digits)
    assert_equal 'laser', CreditCard.brand?('6706123456789012')

    # New format (16 digits)
    assert_equal 'laser', CreditCard.brand?('6709123456789012')

    # Ulster bank (Ireland) with 12 digits
    assert_equal 'laser', CreditCard.brand?('677117111234')
  end

  def test_should_detect_when_an_argument_brand_does_not_match_calculated_brand
    assert CreditCard.matching_brand?('4175001000000000', 'visa')
    assert_false CreditCard.matching_brand?('4175001000000000', 'master')
  end

  def test_detecting_full_range_of_maestro_card_numbers
    maestro = '50000000000'

    assert_equal 11, maestro.length
    assert_not_equal 'maestro', CreditCard.brand?(maestro)

    while maestro.length < 19
      maestro << '0'
      assert_equal 'maestro', CreditCard.brand?(maestro)
    end

    assert_equal 19, maestro.length

    maestro << '0'
    assert_not_equal 'maestro', CreditCard.brand?(maestro)
  end

  def test_matching_discover_card
    assert_equal 'discover', CreditCard.brand?('6011000000000000')
    assert_equal 'discover', CreditCard.brand?('6500000000000000')
    assert_equal 'discover', CreditCard.brand?('6221260000000000')
    assert_equal 'discover', CreditCard.brand?('6450000000000000')

    assert_not_equal 'discover', CreditCard.brand?('6010000000000000')
    assert_not_equal 'discover', CreditCard.brand?('6600000000000000')
  end

  def test_matching_invalid_card
    assert_nil CreditCard.brand?("XXXXXXXXXXXX0000")
    assert_false CreditCard.valid_number?("XXXXXXXXXXXX0000")
  end

  def test_16_digit_maestro_uk
    number = '6759000000000000'
    assert_equal 16, number.length
    assert_equal 'switch', CreditCard.brand?(number)
  end

  def test_18_digit_maestro_uk
    number = '675900000000000000'
    assert_equal 18, number.length
    assert_equal 'switch', CreditCard.brand?(number)
  end

  def test_19_digit_maestro_uk
    number = '6759000000000000000'
    assert_equal 19, number.length
    assert_equal 'switch', CreditCard.brand?(number)
  end
end
