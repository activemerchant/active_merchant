require 'test_helper'

class CreditCardMethodsTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::CreditCardMethods

  class CreditCard
    include ActiveMerchant::Billing::CreditCardMethods
  end

  def maestro_card_numbers
    %w[
      5612590000000000 5817500000000000 5818000000000000
      6390000000000000 6390700000000000 6390990000000000
      6761999999999999 6763000000000000 6799999999999999
    ]
  end

  def non_maestro_card_numbers
    %w[
      4999999999999999 5100000000000000 5599999999999999
      5612709999999999 5817520000000000 5818019999999999
      5912600000000000 6000009999999999 7000000000000000
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
    assert valid_start_year?('2009')
  end

  def test_valid_month_can_handle_strings
    assert valid_month?('1')
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
    assert_equal 'maestro', CreditCard.brand?('675675000000000')

    maestro_card_numbers.each { |number| assert_equal 'maestro', CreditCard.brand?(number) }
    non_maestro_card_numbers.each { |number| assert_not_equal 'maestro', CreditCard.brand?(number) }
  end

  def test_should_detect_mastercard
    assert_equal 'master', CreditCard.brand?('2720890000000000')
    assert_equal 'master', CreditCard.brand?('5413031000000000')
  end

  def test_should_detect_forbrugsforeningen
    assert_equal 'forbrugsforeningen', CreditCard.brand?('6007221000000000')
  end

  def test_should_detect_sodexo_card
    assert_equal 'sodexo', CreditCard.brand?('6060694495764400')
  end

  def test_should_detect_vr_card
    assert_equal 'vr', CreditCard.brand?('6370364495764400')
  end

  def test_should_detect_elo_card
    assert_equal 'elo', CreditCard.brand?('5090510000000000')
    assert_equal 'elo', CreditCard.brand?('5067530000000000')
    assert_equal 'elo', CreditCard.brand?('6277800000000000')
    assert_equal 'elo', CreditCard.brand?('6509550000000000')
  end

  def test_should_detect_alelo_card
    assert_equal 'alelo', CreditCard.brand?('5067490000000010')
    assert_equal 'alelo', CreditCard.brand?('5067700000000028')
    assert_equal 'alelo', CreditCard.brand?('5067600000000036')
    assert_equal 'alelo', CreditCard.brand?('5067600000000044')
  end

  def test_should_detect_naranja_card
    assert_equal 'naranja', CreditCard.brand?('5895627823453005')
    assert_equal 'naranja', CreditCard.brand?('5895620000000002')
    assert_equal 'naranja', CreditCard.brand?('5895626746595650')
  end

  # Alelo BINs beginning with the digit 4 overlap with Visa's range of valid card numbers.
  # We intentionally misidentify these cards as Visa, which works because transactions with
  # such cards will run on Visa rails.
  def test_should_detect_alelo_number_beginning_with_4_as_visa
    assert_equal 'visa', CreditCard.brand?('4025880000000010')
    assert_equal 'visa', CreditCard.brand?('4025880000000028')
    assert_equal 'visa', CreditCard.brand?('4025880000000036')
    assert_equal 'visa', CreditCard.brand?('4025880000000044')
  end

  def test_should_detect_cabal_card
    assert_equal 'cabal', CreditCard.brand?('6044009000000000')
    assert_equal 'cabal', CreditCard.brand?('5896575500000000')
    assert_equal 'cabal', CreditCard.brand?('6035224400000000')
  end

  # UnionPay BINs beginning with 62 overlap with Discover's range of valid card numbers.
  # We intentionally misidentify these cards as Discover, which works because transactions with
  # UnionPay cards will run on Discover rails.
  def test_should_detect_unionpay_cards_beginning_with_62_as_discover
    assert_equal 'discover', CreditCard.brand?('6212345678901265')
    assert_equal 'discover', CreditCard.brand?('6221260000000000')
    assert_equal 'discover', CreditCard.brand?('6250941006528599')
    assert_equal 'discover', CreditCard.brand?('6212345678900000003')
  end

  def test_should_detect_unionpay_card
    assert_equal 'unionpay', CreditCard.brand?('8100000000000000')
    assert_equal 'unionpay', CreditCard.brand?('814400000000000000')
    assert_equal 'unionpay', CreditCard.brand?('8171999927660000')
    assert_equal 'unionpay', CreditCard.brand?('8171999900000000021')
  end

  def test_should_detect_when_an_argument_brand_does_not_match_calculated_brand
    assert CreditCard.matching_brand?('4175001000000000', 'visa')
    assert_false CreditCard.matching_brand?('4175001000000000', 'master')
  end

  def test_detecting_full_range_of_maestro_card_numbers
    maestro = '63900000000'

    assert_equal 11, maestro.length
    assert_not_equal 'maestro', CreditCard.brand?(maestro)

    while maestro.length < 19
      maestro << '0'
      assert_equal 'maestro', CreditCard.brand?(maestro), "Failed for bin #{maestro}"
    end

    assert_equal 19, maestro.length

    maestro << '0'
    assert_not_equal 'maestro', CreditCard.brand?(maestro)
  end

  def test_matching_discover_card
    assert_equal 'discover', CreditCard.brand?('6011000000000000')
    assert_equal 'discover', CreditCard.brand?('6500000000000000')
    assert_equal 'discover', CreditCard.brand?('6450000000000000')

    assert_not_equal 'discover', CreditCard.brand?('6010000000000000')
    assert_not_equal 'discover', CreditCard.brand?('6600000000000000')
  end

  def test_matching_invalid_card
    assert_nil CreditCard.brand?('XXXXXXXXXXXX0000')
    assert_false CreditCard.valid_number?('XXXXXXXXXXXX0000')
    assert_false CreditCard.valid_number?(nil)
  end

  def test_matching_valid_naranja
    number = '5895627823453005'
    assert_equal 'naranja', CreditCard.brand?(number)
    assert CreditCard.valid_number?(number)
  end

  def test_16_digit_maestro_uk
    number = '6759000000000000'
    assert_equal 16, number.length
    assert_equal 'maestro', CreditCard.brand?(number)
  end

  def test_18_digit_maestro_uk
    number = '675900000000000000'
    assert_equal 18, number.length
    assert_equal 'maestro', CreditCard.brand?(number)
  end

  def test_19_digit_maestro_uk
    number = '6759000000000000000'
    assert_equal 19, number.length
    assert_equal 'maestro', CreditCard.brand?(number)
  end

  def test_carnet_cards
    numbers = [
      '5062280000000000',
      '6046220312312312',
      '6393889871239871',
      '5022751231231231'
    ]
    numbers.each do |num|
      assert_equal 16, num.length
      assert_equal 'carnet', CreditCard.brand?(num)
    end
  end

  def test_electron_cards
    # return the card number so assert failures are easy to isolate
    electron_test = Proc.new do |card_number|
      electron = CreditCard.electron?(card_number)
      card_number if electron
    end

    CreditCard::ELECTRON_RANGES.each do |range|
      range.map { |leader| "#{leader}0000000000" }.each do |card_number|
        assert_equal card_number, electron_test.call(card_number)
      end
    end

    # nil check
    assert_false electron_test.call(nil)

    # Visa range
    assert_false electron_test.call('4245180000000000')
    assert_false electron_test.call('4918810000000000')

    # 19 PAN length
    assert electron_test.call('4249620000000000000')

    # 20 PAN length
    assert_false electron_test.call('42496200000000000')
  end

  def test_credit_card?
    assert credit_card.credit_card?
  end
end
