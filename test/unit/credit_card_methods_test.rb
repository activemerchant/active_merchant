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
      5000330000000000 5811499999999999 5010410000000000
      5010630000000000 5892440000000000 5016230000000000
    ]
  end

  def non_maestro_card_numbers
    %w[
      4999999999999999 5100000000000000 5599999999999999
      5612709999999999 5817520000000000 5818019999999999
      5912600000000000 6000009999999999 7000000000000000
    ]
  end

  def maestro_bins
    %w[500032 500057 501015 501016 501018 501020 501021 501023 501024 501025 501026 501027 501028 501029
       501038 501039 501040 501041 501043 501045 501047 501049 501051 501053 501054 501055 501056 501057
       501058 501060 501061 501062 501063 501066 501067 501072 501075 501083 501087 501623
       501800 501089 501091 501092 501095 501104 501105 501107 501108 501500 501879
       502000 502113 502301 503175 503645 503800
       503670 504310 504338 504363 504533 504587 504620 504639 504656 504738 504781 504910
       507001 507002 507004 507082 507090 560014 560565 561033 572402 572610 572626 576904 578614
       585274 585697 586509 588729 588792 589244 589300 589407 589471 589605 589633 589647 589671
       590043 590206 590263 590265
       590278 590361 590362 590379 590393 590590 591235 591420 591481 591620 591770 591948 591994 592024
       592161 592184 592186 592201 592384 592393 592528 592566 592704 592735 592879 592884 593074 593264
       593272 593355 593496 593556 593589 593666 593709 593825 593963 593994 594184 594409 594468 594475
       594581 594665 594691 594710 594874 594968 595355 595364 595532 595547 595561 595568 595743 595929
       596245 596289 596399 596405 596590 596608 596645 596646 596791 596808 596815 596846 597077 597094
       597143 597370 597410 597765 597855 597862 598053 598054 598395 598585 598793 598794 598815 598835
       598838 598880 598889 599000 599069 599089 599148 599191 599310 599741 599742 599867
       601070 604983 601638 606126
       630400 636380 636422 636502 636639 637046 637756 639130 639229 690032]
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
    assert_equal 'diners_club', CreditCard.brand?('3000000000000004')
  end

  def test_should_detect_diners_club_dk
    assert_equal 'diners_club', CreditCard.brand?('30401000000000')
  end

  def test_should_detect_jcb_cards
    assert_equal 'jcb', CreditCard.brand?('3528000000000000')
    assert_equal 'jcb', CreditCard.brand?('3580000000000000')
    assert_equal 'jcb', CreditCard.brand?('3088000000000017')
    assert_equal 'jcb', CreditCard.brand?('3094000000000017')
    assert_equal 'jcb', CreditCard.brand?('3096000000000000')
    assert_equal 'jcb', CreditCard.brand?('3102000000000017')
    assert_equal 'jcb', CreditCard.brand?('3112000000000000')
    assert_equal 'jcb', CreditCard.brand?('3120000000000017')
    assert_equal 'jcb', CreditCard.brand?('3158000000000000')
    assert_equal 'jcb', CreditCard.brand?('3159000000000017')
    assert_equal 'jcb', CreditCard.brand?('3337000000000000')
    assert_equal 'jcb', CreditCard.brand?('3349000000000017')
  end

  def test_should_detect_maestro_dk_as_maestro
    assert_equal 'maestro', CreditCard.brand?('6769271000000000')
  end

  def test_should_detect_maestro_cards
    assert_equal 'maestro', CreditCard.brand?('675675000000000')

    maestro_card_numbers.each { |number| assert_equal 'maestro', CreditCard.brand?(number) }
    maestro_bins.each { |bin| assert_equal 'maestro', CreditCard.brand?("#{bin}0000000000") }
    non_maestro_card_numbers.each { |number| assert_not_equal 'maestro', CreditCard.brand?(number) }
  end

  def test_should_detect_mastercard
    assert_equal 'master', CreditCard.brand?('2720890000000000')
    assert_equal 'master', CreditCard.brand?('5413031000000000')
    assert_equal 'master', CreditCard.brand?('6052721000000000')
    assert_equal 'master', CreditCard.brand?('6062821000000000')
    assert_equal 'master', CreditCard.brand?('6370951000000000')
    assert_equal 'master', CreditCard.brand?('6375681000000000')
    assert_equal 'master', CreditCard.brand?('6375991000000000')
    assert_equal 'master', CreditCard.brand?('6376091000000000')
  end

  def test_should_detect_forbrugsforeningen
    assert_equal 'forbrugsforeningen', CreditCard.brand?('6007221000000000')
  end

  def test_should_detect_sodexo_card_with_six_digits
    assert_equal 'sodexo', CreditCard.brand?('6060694495764400')
    assert_equal 'sodexo', CreditCard.brand?('6060714495764400')
    assert_equal 'sodexo', CreditCard.brand?('6033894495764400')
    assert_equal 'sodexo', CreditCard.brand?('6060704495764400')
    assert_equal 'sodexo', CreditCard.brand?('6060684495764400')
    assert_equal 'sodexo', CreditCard.brand?('6008184495764400')
    assert_equal 'sodexo', CreditCard.brand?('5058644495764400')
    assert_equal 'sodexo', CreditCard.brand?('5058654495764400')
  end

  def test_should_detect_sodexo_card_with_eight_digits
    assert_equal 'sodexo', CreditCard.brand?('6060760195764400')
    assert_equal 'sodexo', CreditCard.brand?('6060760795764400')
    assert_equal 'sodexo', CreditCard.brand?('6089440095764400')
    assert_equal 'sodexo', CreditCard.brand?('6089441095764400')
    assert_equal 'sodexo', CreditCard.brand?('6089442095764400')
    assert_equal 'sodexo', CreditCard.brand?('6060760695764400')
  end

  def test_should_detect_alia_card
    assert_equal 'alia', CreditCard.brand?('5049970000000000')
    assert_equal 'alia', CreditCard.brand?('5058780000000000')
    assert_equal 'alia', CreditCard.brand?('6010300000000000')
    assert_equal 'alia', CreditCard.brand?('6010730000000000')
    assert_equal 'alia', CreditCard.brand?('5058740000000000')
  end

  def test_should_detect_mada_card
    assert_equal 'mada', CreditCard.brand?('5043000000000000')
    assert_equal 'mada', CreditCard.brand?('5852650000000000')
    assert_equal 'mada', CreditCard.brand?('5888500000000000')
    assert_equal 'mada', CreditCard.brand?('6361200000000000')
    assert_equal 'mada', CreditCard.brand?('9682040000000000')
  end

  def test_alia_number_not_validated
    10.times do
      number = rand(5058740000000001..5058749999999999).to_s
      assert_equal 'alia', CreditCard.brand?(number)
      assert CreditCard.valid_number?(number)
    end
  end

  def test_should_detect_confiable_card
    assert_equal 'confiable', CreditCard.brand?('5607180000000000')
  end

  def test_should_detect_bp_plus_card
    assert_equal 'bp_plus', CreditCard.brand?('70501 501021600 378')
    assert_equal 'bp_plus', CreditCard.brand?('70502 111111111 111')
    assert_equal 'bp_plus', CreditCard.brand?('7050 15605297 00114')
    assert_equal 'bp_plus', CreditCard.brand?('7050 15546992 00062')
  end

  def test_should_validate_bp_plus_card
    assert_true CreditCard.valid_number?('70501 501021600 378')
    assert_true CreditCard.valid_number?('7050 15605297 00114')
    assert_true CreditCard.valid_number?('7050 15546992 00062')
    assert_true CreditCard.valid_number?('7050 16150146 00110')
    assert_true CreditCard.valid_number?('7050 16364764 00070')

    # numbers with invalid formats
    assert_false CreditCard.valid_number?('7050_15546992_00062')
    assert_false CreditCard.valid_number?('70501 55469920 0062')
    assert_false CreditCard.valid_number?('70 501554699 200062')

    # numbers that are luhn-invalid
    assert_false CreditCard.valid_number?('70502 111111111 111')
    assert_false CreditCard.valid_number?('7050 16364764 00071')
    assert_false CreditCard.valid_number?('7050 16364764 00072')
  end

  def test_confiable_number_not_validated
    10.times do
      number = rand(5607180000000001..5607189999999999).to_s
      assert_equal 'confiable', CreditCard.brand?(number)
      assert CreditCard.valid_number?(number)
    end
  end

  def test_should_detect_maestro_no_luhn_card
    assert_equal 'maestro_no_luhn', CreditCard.brand?('5010800000000000')
    assert_equal 'maestro_no_luhn', CreditCard.brand?('5010810000000000')
    assert_equal 'maestro_no_luhn', CreditCard.brand?('5010820000000000')
    assert_equal 'maestro_no_luhn', CreditCard.brand?('501082000000')
    assert_equal 'maestro_no_luhn', CreditCard.brand?('5010820000000000000')
  end

  def test_maestro_no_luhn_number_not_validated
    10.times do
      number = rand(5010800000000001..5010829999999999).to_s
      assert_equal 'maestro_no_luhn', CreditCard.brand?(number)
      assert CreditCard.valid_number?(number)
    end
  end

  def test_should_detect_olimpica_card
    assert_equal 'olimpica', CreditCard.brand?('6368530000000000')
  end

  def test_should_detect_sodexo_no_luhn_card
    number1 = '5058645584812145'
    number2 = '5058655584812145'
    assert_equal 'sodexo', CreditCard.brand?(number1)
    assert CreditCard.valid_number?(number1)
    assert_equal 'sodexo', CreditCard.brand?(number2)
    assert CreditCard.valid_number?(number2)
  end

  def test_should_validate_sodexo_no_luhn_card
    assert_true CreditCard.valid_number?('5058645584812145')
    assert_false CreditCard.valid_number?('5058665584812110')
  end

  def test_should_detect_passcard_card
    assert_equal 'passcard', CreditCard.brand?('6280260025383009')
    assert_equal 'passcard', CreditCard.brand?('6280260025383280')
    assert_equal 'passcard', CreditCard.brand?('6280260025383298')
    assert_equal 'passcard', CreditCard.brand?('6280260025383306')
    assert_equal 'passcard', CreditCard.brand?('6280260025383314')
  end

  def test_should_validate_passcard_card
    assert_true CreditCard.valid_number?('6280260025383009')
    # numbers with invalid formats
    assert_false CreditCard.valid_number?('6280_26002538_0005')
    # numbers that are luhn-invalid
    assert_false CreditCard.valid_number?('6280260025380991')
  end

  def test_should_detect_edenred_card
    assert_equal 'edenred', CreditCard.brand?('6374830000000823')
    assert_equal 'edenred', CreditCard.brand?('6374830000000799')
    assert_equal 'edenred', CreditCard.brand?('6374830000000807')
    assert_equal 'edenred', CreditCard.brand?('6374830000000815')
    assert_equal 'edenred', CreditCard.brand?('6374830000000823')
  end

  def test_should_validate_edenred_card
    assert_true CreditCard.valid_number?('6374830000000369')
    # numbers with invalid formats
    assert_false CreditCard.valid_number?('6374 8300000 00369')
    # numbers that are luhn-invalid
    assert_false CreditCard.valid_number?('6374830000000111')
  end

  def test_should_detect_anda_card
    assert_equal 'anda', CreditCard.brand?('6031998427187914')
  end

  # Creditos directos a.k.a tarjeta d
  def test_should_detect_tarjetad_card
    assert_equal 'tarjeta-d', CreditCard.brand?('6018282227431033')
  end

  def test_should_detect_creditel_card
    assert_equal 'creditel', CreditCard.brand?('6019330047539016')
  end

  def test_should_detect_vr_card
    assert_equal 'vr', CreditCard.brand?('6370364495764400')
    assert_equal 'vr', CreditCard.brand?('6274160000000001')
  end

  def test_should_detect_elo_card
    assert_equal 'elo', CreditCard.brand?('5090510000000000')
    assert_equal 'elo', CreditCard.brand?('5067530000000000')
    assert_equal 'elo', CreditCard.brand?('6277800000000000')
    assert_equal 'elo', CreditCard.brand?('6509550000000000')
    assert_equal 'elo', CreditCard.brand?('5090890000000000')
    assert_equal 'elo', CreditCard.brand?('5092570000000000')
    assert_equal 'elo', CreditCard.brand?('5094100000000000')
  end

  def test_should_detect_alelo_card
    assert_equal 'alelo', CreditCard.brand?('5067490000000010')
    assert_equal 'alelo', CreditCard.brand?('5067700000000028')
    assert_equal 'alelo', CreditCard.brand?('5067600000000036')
    assert_equal 'alelo', CreditCard.brand?('5067600000000044')
    assert_equal 'alelo', CreditCard.brand?('5099920000000000')
    assert_equal 'alelo', CreditCard.brand?('5067630000000000')
    assert_equal 'alelo', CreditCard.brand?('5098870000000000')
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
    assert_equal 'cabal', CreditCard.brand?('6502723300000000')
    assert_equal 'cabal', CreditCard.brand?('6500870000000000')
    assert_equal 'cabal', CreditCard.brand?('6509000000000000')
  end

  def test_should_detect_unionpay_card
    assert_equal 'unionpay', CreditCard.brand?('6221260000000000')
    assert_equal 'unionpay', CreditCard.brand?('6250941006528599')
    assert_equal 'unionpay', CreditCard.brand?('6282000000000000')
    assert_equal 'unionpay', CreditCard.brand?('8100000000000000')
    assert_equal 'unionpay', CreditCard.brand?('814400000000000000')
    assert_equal 'unionpay', CreditCard.brand?('8171999927660000')
    assert_equal 'unionpay', CreditCard.brand?('8171999900000000021')
    assert_equal 'unionpay', CreditCard.brand?('6200000000000005')
    assert_equal 'unionpay', CreditCard.brand?('6217857000000000')
  end

  def test_should_detect_synchrony_card
    assert_equal 'synchrony', CreditCard.brand?('7006000000000000')
  end

  def test_should_detect_routex_card
    number = '7006760000000000000'
    assert_equal 'routex', CreditCard.brand?(number)
    assert CreditCard.valid_number?(number)
    assert_equal 'routex', CreditCard.brand?('7006789224703725591')
    assert_equal 'routex', CreditCard.brand?('7006740000000000013')
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

  def test_matching_valid_creditel
    number = '6019330047539016'
    assert_equal 'creditel', CreditCard.brand?(number)
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
    numbers = %w[
      5062280000000000
      6046220312312312
      6393889871239871
      5022751231231231
      6275350000000001
    ]
    numbers.each do |num|
      assert_equal 16, num.length
      assert_equal 'carnet', CreditCard.brand?(num)
    end
  end

  def test_should_detect_cartes_bancaires_cards
    assert_equal 'cartes_bancaires', CreditCard.brand?('5855010000000000')
    assert_equal 'cartes_bancaires', CreditCard.brand?('5075935000000000')
    assert_equal 'cartes_bancaires', CreditCard.brand?('5075901100000000')
    assert_equal 'cartes_bancaires', CreditCard.brand?('5075890130000000')
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

  def test_should_detect_panal_card
    assert_equal 'panal', CreditCard.brand?('6020490000000000')
  end

  def test_detecting_full_range_of_verve_card_numbers
    verve = '506099000000000'

    assert_equal 15, verve.length
    assert_not_equal 'verve', CreditCard.brand?(verve)

    4.times do
      verve << '0'
      assert_equal 'verve', CreditCard.brand?(verve), "Failed for bin #{verve}"
    end

    assert_equal 19, verve.length

    verve << '0'
    assert_not_equal 'verve', CreditCard.brand?(verve)
  end

  def test_should_detect_verve
    credit_cards = %w[5060990000000000
                      506112100000000000
                      5061351000000000000
                      5061591000000000
                      506175100000000000
                      5078801000000000000
                      5079381000000000
                      637058100000000000
                      5079400000000000000
                      507879000000000000
                      5061930000000000
                      506136000000000000]
    credit_cards.all? { |cc| CreditCard.brand?(cc) == 'verve' }
  end

  def test_should_detect_tuya_card
    assert_equal 'tuya', CreditCard.brand?('5888000000000000')
  end

  def test_should_validate_tuya_card
    assert_true CreditCard.valid_number?('5888001211111111')
    # numbers with invalid formats
    assert_false CreditCard.valid_number?('5888_0000_0000_0030')
  end

  def test_credit_card?
    assert credit_card.credit_card?
  end
end
