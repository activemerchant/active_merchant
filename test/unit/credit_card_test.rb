require 'test_helper'

class CreditCardTest < Test::Unit::TestCase
  def setup
    CreditCard.require_verification_value = false
    @visa = credit_card("4779139500118580",   :brand => "visa")
    @solo = credit_card("676700000000000000", :brand => "solo", :issue_number => '01')
  end

  def teardown
    CreditCard.require_verification_value = false
  end

  def test_constructor_should_properly_assign_values
    c = credit_card

    assert_equal "4242424242424242", c.number
    assert_equal 9, c.month
    assert_equal Time.now.year + 1, c.year
    assert_equal "Longbob Longsen", c.name
    assert_equal "visa", c.brand
    assert_valid c
  end

  def test_new_credit_card_should_not_be_valid
    c = CreditCard.new

    assert_not_valid c
  end

  def test_should_be_a_valid_visa_card
    assert_valid @visa
  end

  def test_should_be_a_valid_solo_card
    assert_valid @solo
  end

  def test_cards_with_empty_names_should_not_be_valid
    @visa.first_name = ''
    @visa.last_name  = ''

    assert_not_valid @visa
  end

  def test_should_be_able_to_liberate_a_bogus_card
    c = credit_card('', :brand => 'bogus')
    assert_valid c

    c.brand = 'visa'
    assert_not_valid c
  end

  def test_should_be_able_to_identify_invalid_card_numbers
    @visa.number = nil
    assert_not_valid @visa

    @visa.number = "11112222333344ff"
    errors = assert_not_valid @visa
    assert !errors[:type]
    assert !errors[:brand]
    assert errors[:number]

    @visa.number = "111122223333444"
    errors = assert_not_valid @visa
    assert !errors[:type]
    assert !errors[:brand]
    assert errors[:number]

    @visa.number = "11112222333344444"
    errors = assert_not_valid @visa
    assert !errors[:type]
    assert !errors[:brand]
    assert errors[:number]
  end

  def test_should_have_errors_with_invalid_card_brand_for_otherwise_correct_number
    @visa.brand = 'master'

    errors = assert_not_valid @visa
    assert !errors[:number]
    assert errors[:brand]
    assert_equal ["does not match the card number"], errors[:brand]
  end

  def test_should_be_invalid_when_brand_cannot_be_detected
    @visa.brand = nil

    @visa.number = nil
    errors = assert_not_valid @visa
    assert !errors[:brand]
    assert !errors[:type]
    assert errors[:number]
    assert_equal ['is required'], errors[:number]

    @visa.number = "11112222333344ff"
    errors = assert_not_valid @visa
    assert !errors[:type]
    assert !errors[:brand]
    assert errors[:number]

    @visa.number = "11112222333344444"
    errors = assert_not_valid @visa
    assert !errors[:brand]
    assert !errors[:type]
    assert errors[:number]
  end

  def test_should_be_a_valid_card_number
    @visa.number = "4242424242424242"

    assert_valid @visa
  end

  def test_should_require_a_valid_card_month
    @visa.month  = Time.now.utc.month
    @visa.year   = Time.now.utc.year

    assert_valid @visa
  end

  def test_should_not_be_valid_with_empty_month
    @visa.month = ''

    errors = assert_not_valid @visa
    assert_equal ['is required'], errors[:month]
  end

  def test_should_not_be_valid_for_edge_month_cases
    @visa.month = 13
    @visa.year = Time.now.year
    errors = assert_not_valid @visa
    assert errors[:month]

    @visa.month = 0
    @visa.year = Time.now.year
    errors = assert_not_valid @visa
    assert errors[:month]
  end

  def test_should_be_invalid_with_empty_year
    @visa.year = ''
    errors = assert_not_valid @visa
    assert_equal ['is required'], errors[:year]
  end

  def test_should_not_be_valid_for_edge_year_cases
    @visa.year  = Time.now.year - 1
    errors = assert_not_valid @visa
    assert errors[:year]

    @visa.year  = Time.now.year + 21
    errors = assert_not_valid @visa
    assert errors[:year]
  end

  def test_should_be_a_valid_future_year
    @visa.year = Time.now.year + 1
    assert_valid @visa
  end

  def test_expired_card_should_have_one_error_on_year
    @visa.year = Time.now.year - 1
    errors = assert_not_valid(@visa)
    assert_not_nil errors[:year]
    assert_equal 1, errors[:year].size
    assert_match(/expired/, errors[:year].first)
  end

  def test_should_be_valid_with_start_month_and_year_as_string
    @solo.start_month = '2'
    @solo.start_year = '2007'
    assert_valid @solo
  end

  def test_should_identify_wrong_card_brand
    c = credit_card(:brand => 'master')
    assert_not_valid c
  end

  def test_should_display_number
    assert_equal 'XXXX-XXXX-XXXX-1234', CreditCard.new(:number => '1111222233331234').display_number
    assert_equal 'XXXX-XXXX-XXXX-1234', CreditCard.new(:number => '111222233331234').display_number
    assert_equal 'XXXX-XXXX-XXXX-1234', CreditCard.new(:number => '1112223331234').display_number

    assert_equal 'XXXX-XXXX-XXXX-', CreditCard.new(:number => nil).display_number
    assert_equal 'XXXX-XXXX-XXXX-', CreditCard.new(:number => '').display_number
    assert_equal 'XXXX-XXXX-XXXX-123', CreditCard.new(:number => '123').display_number
    assert_equal 'XXXX-XXXX-XXXX-1234', CreditCard.new(:number => '1234').display_number
    assert_equal 'XXXX-XXXX-XXXX-1234', CreditCard.new(:number => '01234').display_number
  end

  def test_should_correctly_identify_card_brand
    assert_equal 'visa',             CreditCard.brand?('4242424242424242')
    assert_equal 'american_express', CreditCard.brand?('341111111111111')
    assert_nil CreditCard.brand?('')
  end

  def test_should_be_able_to_require_a_verification_value
    CreditCard.require_verification_value = true
    assert CreditCard.requires_verification_value?
  end

  def test_should_not_be_valid_when_requiring_a_verification_value
    CreditCard.require_verification_value = true
    card = credit_card('4242424242424242', :verification_value => nil)
    assert_not_valid card

    card.verification_value = '1234'
    errors = assert_not_valid card
    assert_equal errors[:verification_value], ['should be 3 digits']

    card.verification_value = '123'
    assert_valid card

    card = credit_card('341111111111111', :verification_value => '123', :brand => 'american_express')
    errors = assert_not_valid card
    assert_equal errors[:verification_value], ['should be 4 digits']

    card.verification_value = '1234'
    assert_valid card
  end

  def test_bogus_cards_are_not_valid_without_verification_value
    CreditCard.require_verification_value = true
    card = credit_card('1', brand: 'bogus', verification_value: nil)
    assert_not_valid card
  end

  def test_should_require_valid_start_date_for_solo_or_switch
    @solo.start_month  = nil
    @solo.start_year   = nil
    @solo.issue_number = nil

    errors = assert_not_valid @solo
    assert errors[:start_month]
    assert errors[:start_year]
    assert errors[:issue_number]

    @solo.start_month = 2
    @solo.start_year  = 2007
    assert_valid @solo
  end

  def test_should_require_a_valid_issue_number_for_solo_or_switch
    @solo.start_month  = nil
    @solo.start_year   = 2005
    @solo.issue_number = nil

    errors = assert_not_valid @solo
    assert errors[:start_month]
    assert_equal ["cannot be empty"], errors[:issue_number]

    @solo.issue_number = 3
    assert_valid @solo
  end

  def test_should_require_a_validate_non_empty_issue_number_for_solo_or_switch
    @solo.issue_number = "invalid"

    errors = assert_not_valid @solo
    assert_equal ["is invalid"], errors[:issue_number]

    @solo.issue_number = 3
    assert_valid @solo
  end

  def test_should_return_last_four_digits_of_card_number
    ccn = CreditCard.new(:number => "4779139500118580")
    assert_equal "8580", ccn.last_digits
  end

  def test_bogus_last_digits
    ccn = CreditCard.new(:number => "1")
    assert_equal "1", ccn.last_digits
  end

  def test_should_return_first_four_digits_of_card_number
    ccn = CreditCard.new(:number => "4779139500118580")
    assert_equal "477913", ccn.first_digits
  end

  def test_should_return_first_bogus_digit_of_card_number
    ccn = CreditCard.new(:number => "1")
    assert_equal "1", ccn.first_digits
  end

  def test_should_be_true_when_credit_card_has_a_first_name
    c = CreditCard.new
    assert_false c.first_name?

    c = CreditCard.new(:first_name => 'James')
    assert c.first_name?
  end

  def test_should_be_true_when_credit_card_has_a_last_name
    c = CreditCard.new
    assert_false c.last_name?

    c = CreditCard.new(:last_name => 'Herdman')
    assert c.last_name?
  end

  def test_should_test_for_a_full_name
    c = CreditCard.new
    assert_false c.name?

    c = CreditCard.new(:first_name => 'James', :last_name => 'Herdman')
    assert c.name?
  end

  def test_should_handle_full_name_when_first_or_last_is_missing
    c = CreditCard.new(:first_name => 'James')
    assert c.name?
    assert_equal "James", c.name

    c = CreditCard.new(:last_name => 'Herdman')
    assert c.name?
    assert_equal "Herdman", c.name
  end

  def test_should_assign_a_full_name
    c = CreditCard.new :name => "James Herdman"
    assert_equal "James", c.first_name
    assert_equal "Herdman", c.last_name

    c = CreditCard.new :name => "Rocket J. Squirrel"
    assert_equal "Rocket J.", c.first_name
    assert_equal "Squirrel", c.last_name

    c = CreditCard.new :name => "Twiggy"
    assert_equal "", c.first_name
    assert_equal "Twiggy", c.last_name
  end

  # The following is a regression for a bug that raised an exception when
  # a new credit card was validated
  def test_validate_new_card
    credit_card = CreditCard.new

    assert_nothing_raised do
      credit_card.validate
    end
  end

  # The following is a regression for a bug where the keys of the
  # credit card card_companies hash were not duped when detecting the brand
  def test_create_and_validate_credit_card_from_brand
    credit_card = CreditCard.new(:brand => CreditCard.brand?('4242424242424242'))
    assert_nothing_raised do
      credit_card.validate
    end
  end

  def test_autodetection_of_credit_card_brand
    credit_card = CreditCard.new(:number => '4242424242424242')
    assert_equal 'visa', credit_card.brand
  end

  def test_card_brand_should_not_be_autodetected_when_provided
    credit_card = CreditCard.new(:number => '4242424242424242', :brand => 'master')
    assert_equal 'master', credit_card.brand
  end

  def test_detecting_bogus_card
    credit_card = CreditCard.new(:number => '1')
    assert_equal 'bogus', credit_card.brand
  end

  def test_validating_bogus_card
    credit_card = credit_card('1', :brand => nil)
    assert_valid credit_card
  end

  def test_mask_number
    assert_equal 'XXXX-XXXX-XXXX-5100', CreditCard.mask('5105105105105100')
  end

  def test_strip_non_digit_characters
    card = credit_card('4242-4242      %%%%%%4242......4242')
    assert_valid card
    assert_equal "4242424242424242", card.number
  end

  def test_validate_handles_blank_number
    card = credit_card(nil)
    assert_not_valid card
    assert_nil card.number
  end

  def test_rails_methods_are_deprecated
    card = credit_card
    warning = %(Implicit inclusion of Rails-specific functionality is deprecated. Explicitly require "active_merchant/billing/rails" if you need it.)
    assert_deprecation_warning(warning) do
      card.valid?
    end

    assert_deprecation_warning(warning) do
      card.errors
    end
  end

  def test_brand_is_aliased_as_type
    assert_deprecation_warning("CreditCard#type is deprecated and will be removed from a future release of ActiveMerchant. Please use CreditCard#brand instead.") do
      assert_equal @visa.type, @visa.brand
    end
    assert_deprecation_warning("CreditCard#type is deprecated and will be removed from a future release of ActiveMerchant. Please use CreditCard#brand instead.") do
      assert_equal @solo.type, @solo.brand
    end
  end

  def test_month_and_year_are_immediately_converted_to_integers
    card = CreditCard.new

    card.month = "1"
    assert_equal 1, card.month
    card.year = "1"
    assert_equal 1, card.year

    card.month = ""
    assert_nil card.month
    card.year = ""
    assert_nil card.year

    card.month = nil
    assert_nil card.month
    card.year = nil
    assert_nil card.year

    card.start_month = "1"
    assert_equal 1, card.start_month
    card.start_year = "1"
    assert_equal 1, card.start_year
  end
end
