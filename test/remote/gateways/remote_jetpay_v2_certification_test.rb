require 'test_helper'

class RemoteJetpayV2CertificationTest < Test::Unit::TestCase

  def setup
    @gateway = JetpayV2Gateway.new(fixtures(:jetpay_v2))

    @unique_id = ''

    @options = {
      :device => 'spreedly',
      :application => 'spreedly',
      :developer_id => 'GenkID',
      :billing_address => address(:address1 => '1234 Fifth Street', :address2 => '', :city => 'Beaumont', :state => 'TX', :country => 'US', :zip => '77708'),
      :shipping_address => address(:address1 => '1234 Fifth Street', :address2 => '', :city => 'Beaumont', :state => 'TX', :country => 'US', :zip => '77708'),
      :email => 'test@test.com',
      :ip => '127.0.0.1'
    }
  end

  def teardown
    puts "\n#{@options[:order_id]}: #{@unique_id}"
  end

  def test_certification_cnp1_authorize_mastercard
    @options[:order_id] = "CNP1"
    amount = 1000
    master = credit_card('5111111111111118', :month => 12, :year => 2017, :brand => 'master', :verification_value => '121')
    assert response = @gateway.authorize(amount, master, @options)
    assert_success response
    assert_equal "APPROVED", response.message
    @unique_id = response.params['unique_id']
  end

  def test_certification_cnp2_authorize_visa
    @options[:order_id] = "CNP2"
    amount = 1105
    visa   = credit_card('4111111111111111', :month => 12, :year => 2017, :brand => 'visa', :verification_value => '121')
    assert response = @gateway.authorize(amount, visa, @options)
    assert_failure response
    assert_equal "Do not honor.", response.message
    @unique_id = response.params['unique_id']
  end

  def test_certification_cnp3_cnp4_authorize_and_capture_amex
    @options[:order_id] = "CNP3"
    amount = 1200
    amex = credit_card('378282246310005', :month => 12, :year => 2017, :brand => 'american_express', :verification_value => '1221')
    assert response = @gateway.authorize(amount, amex, @options)
    assert_success response
    assert_equal "APPROVED", response.message
    @unique_id = response.params['unique_id']
    puts "\n#{@options[:order_id]}: #{@unique_id}"

    @options[:order_id] = "CNP4"
    assert response = @gateway.capture(amount, response.authorization, @options)
    assert_success response
    @unique_id = response.params['unique_id']
  end

  def test_certification_cnp5_purchase_discover
    @options[:order_id] = "CNP5"
    amount = 1300
    discover = credit_card('6011111111111117', :month => 12, :year => 2017, :brand => 'discover', :verification_value => '121')
    assert response = @gateway.purchase(amount, discover, @options)
    assert_success response
    assert_equal "APPROVED", response.message
    @unique_id = response.params['unique_id']
  end

  def test_certification_cnp6_purchase_visa
    @options[:order_id] = "CNP6"
    amount = 1405
    visa   = credit_card('4111111111111111', :month => 12, :year => 2017, :brand => 'visa', :verification_value => '120')
    assert response = @gateway.purchase(amount, visa, @options)
    assert_failure response
    assert_equal "Do not honor.", response.message
    @unique_id = response.params['unique_id']
  end

  def test_certification_cnp7_authorize_mastercard
    @options[:order_id] = "CNP7"
    amount = 1500
    master = credit_card('5111111111111118', :month => 12, :year => 2017, :brand => 'master', :verification_value => '120')
    assert response = @gateway.authorize(amount, master, @options)
    assert_success response
    assert_equal "APPROVED", response.message
    @unique_id = response.params['unique_id']
  end

  def test_certification_cnp8_authorize_visa
    @options[:order_id] = "CNP8"
    amount = 1605
    visa   = credit_card('4111111111111111', :month => 12, :year => 2017, :brand => 'visa', :verification_value => '120')
    assert response = @gateway.authorize(amount, visa, @options)
    assert_failure response
    assert_equal "Do not honor.", response.message
    @unique_id = response.params['unique_id']
  end

  def test_certification_cnp9_cnp10_authorize_and_capture_amex
    @options[:order_id] = "CNP9"
    amount = 1700
    amex = credit_card('378282246310005', :month => 12, :year => 2017, :brand => 'american_express', :verification_value => '1220')
    assert response = @gateway.authorize(amount, amex, @options)
    assert_success response
    assert_equal "APPROVED", response.message
    @unique_id = response.params['unique_id']
    puts "\n#{@options[:order_id]}: #{@unique_id}"

    @options[:order_id] = "CNP10"
    assert response = @gateway.capture(amount, response.authorization, @options)
    assert_success response
    @unique_id = response.params['unique_id']
  end

  def test_certification_cnp11_purchase_discover
    @options[:order_id] = "CNP11"
    amount = 1800
    discover = credit_card('6011111111111117', :month => 12, :year => 2017, :brand => 'discover', :verification_value => '120')
    assert response = @gateway.purchase(amount, discover, @options)
    assert_success response
    assert_equal "APPROVED", response.message
    @unique_id = response.params['unique_id']
  end

  def test_certification_rec01_recurring_mastercard
    @options[:order_id] = "REC01"
    @options[:origin] = "RECURRING"
    @options[:billing_address] = nil
    @options[:shipping_address] = nil
    amount = 2000
    master = credit_card('5111111111111118', :month => 12, :year => 2017, :brand => 'master', :verification_value => '120')
    assert response = @gateway.purchase(amount, master, @options)
    assert_success response
    assert_equal "APPROVED", response.message
    @unique_id = response.params['unique_id']
  end

  def test_certification_rec02_recurring_visa
    @options[:order_id] = "REC02"
    @options[:origin] = "RECURRING"
    amount = 2100
    visa   = credit_card('4111111111111111', :month => 12, :year => 2017, :brand => 'visa', :verification_value => '')
    assert response = @gateway.purchase(amount, visa, @options)
    assert_success response
    assert_equal "APPROVED", response.message
    @unique_id = response.params['unique_id']
  end

  def test_certification_rec03_recurring_amex
    @options[:order_id] = "REC03"
    @options[:origin] = "RECURRING"
    amount = 2200
    amex = credit_card('378282246310005', :month => 12, :year => 2017, :brand => 'american_express', :verification_value => '1221')
    assert response = @gateway.purchase(amount, amex, @options)
    assert_success response
    assert_equal "APPROVED", response.message
    @unique_id = response.params['unique_id']
  end

  def test_certification_corp07_corp08_authorize_and_capture_discover
    @options[:order_id] = "CORP07"
    amount = 2500
    discover = credit_card('6011111111111117', :month => 12, :year => 2018, :brand => 'discover', :verification_value => '120')
    assert response = @gateway.authorize(amount, discover, @options)
    assert_success response
    assert_equal "APPROVED", response.message
    @unique_id = response.params['unique_id']
    puts "\n#{@options[:order_id]}: #{@unique_id}"

    @options[:order_id] = "CORP08"
    assert response = @gateway.capture(amount, response.authorization, @options.merge(:tax_amount => "200"))
    assert_success response
    @unique_id = response.params['unique_id']
  end

  def test_certification_corp09_corp10_authorize_and_capture_visa
    @options[:order_id] = "CORP09"
    amount = 5000
    visa   = credit_card('4111111111111111', :month => 12, :year => 2018, :brand => 'visa', :verification_value => '120')
    assert response = @gateway.authorize(amount, visa, @options)
    assert_success response
    assert_equal "APPROVED", response.message
    @unique_id = response.params['unique_id']
    puts "\n#{@options[:order_id]}: #{@unique_id}"

    @options[:order_id] = "CORP10"
    assert response = @gateway.capture(amount, response.authorization, @options.merge(:tax_amount => "0", :tax_exempt => "true"))
    assert_success response
    @unique_id = response.params['unique_id']
  end

  def test_certification_corp11_corp12_authorize_and_capture_mastercard
    @options[:order_id] = "CORP11"
    amount = 7500
    master = credit_card('5111111111111118', :month => 12, :year => 2018, :brand => 'master', :verification_value => '120')
    assert response = @gateway.authorize(amount, master, @options)
    assert_success response
    assert_equal "APPROVED", response.message
    @unique_id = response.params['unique_id']
    puts "\n#{@options[:order_id]}: #{@unique_id}"

    @options[:order_id] = "CORP12"
    assert response = @gateway.capture(amount, response.authorization, @options.merge(:tax_amount => "0", :tax_exempt => "false", :purchase_order => '456456'))
    assert_success response
    @unique_id = response.params['unique_id']
  end

  def test_certification_cred02_credit_visa
    @options[:order_id] = "CRED02"
    amount = 100
    visa   = credit_card('4111111111111111', :month => 12, :year => 2017, :brand => 'visa', :verification_value => '120')
    assert response = @gateway.credit(amount, visa, @options)
    assert_success response
    assert_equal "APPROVED", response.message
    @unique_id = response.params['unique_id']
  end

  def test_certification_cred03_credit_amex
    @options[:order_id] = "CRED03"
    amount = 200
    amex = credit_card('378282246310005', :month => 12, :year => 2017, :brand => 'american_express', :verification_value => '1220')
    assert response = @gateway.credit(amount, amex, @options)
    assert_success response
    assert_equal "APPROVED", response.message
    @unique_id = response.params['unique_id']
  end

  def test_certification_void03_void04_purchase_void_visa
    @options[:order_id] = "VOID03"
    amount = 300
    visa   = credit_card('4111111111111111', :month => 12, :year => 2017, :brand => 'visa', :verification_value => '120')
    assert response = @gateway.purchase(amount, visa, @options)
    assert_success response
    assert_equal "APPROVED", response.message
    @unique_id = response.params['unique_id']
    puts "\n#{@options[:order_id]}: #{@unique_id}"

    @options[:order_id] = "VOID04"
    transaction_id, approval, amount, token = response.authorization.split(";")
    amount = 500
    authorization = [transaction_id, approval, amount, token].join(";")
    assert response = @gateway.void(authorization, @options)
    assert_failure response
    @unique_id = response.params['unique_id']
  end

  def test_certification_void07_void08_void09_authorize_capture_void_discover
    @options[:order_id] = "VOID07"
    amount = 400
    discover = credit_card('6011111111111117', :month => 12, :year => 2017, :brand => 'discover', :verification_value => '120')
    assert response = @gateway.authorize(amount, discover, @options)
    assert_success response
    assert_equal "APPROVED", response.message
    @unique_id = response.params['unique_id']
    puts "\n#{@options[:order_id]}: #{@unique_id}"

    @options[:order_id] = "VOID08"
    amount = 600
    assert response = @gateway.capture(amount, response.authorization, @options)
    assert_success response
    @unique_id = response.params['unique_id']
    puts "\n#{@options[:order_id]}: #{@unique_id}"

    @options[:order_id] = "VOID09"
    assert response = @gateway.void(response.authorization, @options)
    assert_success response
    @unique_id = response.params['unique_id']
  end

  def test_certification_void12_void13_credit_void_visa
    @options[:order_id] = "VOID12"
    amount = 800
    visa   = credit_card('4111111111111111', :month => 12, :year => 2017, :brand => 'visa', :verification_value => '120')
    assert response = @gateway.credit(amount, visa, @options)
    assert_success response
    assert_equal "APPROVED", response.message
    @unique_id = response.params['unique_id']
    puts "\n#{@options[:order_id]}: #{@unique_id}"

    @options[:order_id] = "VOID13"
    assert response = @gateway.void(response.authorization, @options)
    assert_success response
    @unique_id = response.params['unique_id']
  end

  def test_certification_tok15_tokenize_mastercard
    @options[:order_id] = "TOK15"
    master = credit_card('5111111111111118', :month => 12, :year => 2017, :brand => 'master', :verification_value => '101')
    assert response = @gateway.store(master, @options)
    assert_success response
    assert_equal "APPROVED", response.message
    assert_equal "TOKENIZED", response.params["response_text"]
    @unique_id = response.params['unique_id']
  end

  def test_certification_tok16_authorize_with_token_request_visa
    @options[:order_id] = "TOK16"
    amount = 3100
    visa   = credit_card('4111111111111111', :month => 12, :year => 2017, :brand => 'visa', :verification_value => '101')
    assert response = @gateway.authorize(amount, visa, @options)
    assert_success response
    assert_equal "APPROVED", response.message
    transaction_id, approval, amount, token = response.authorization.split(";")
    assert_equal token, response.params["token"]
    @unique_id = response.params['unique_id']
  end

  def test_certification_tok17_purchase_with_token_request_amex
    @options[:order_id] = "TOK17"
    amount = 3200
    amex = credit_card('378282246310005', :month => 12, :year => 2017, :brand => 'american_express', :verification_value => '1001')
    assert response = @gateway.purchase(amount, amex, @options)
    assert_success response
    assert_equal "APPROVED", response.message
    transaction_id, approval, amount, token = response.authorization.split(";")
    assert_equal token, response.params["token"]
    @unique_id = response.params['unique_id']
  end

  def test_certification_tok18_authorize_using_token_mastercard
    master = credit_card('5111111111111118', :month => 12, :year => 2017, :brand => 'master', :verification_value => '101')
    assert response = @gateway.store(master, @options)
    assert_success response

    @options[:order_id] = "TOK18"
    amount = 3300
    assert response = @gateway.authorize(amount, response.authorization, @options)
    assert_success response
    assert_equal "APPROVED", response.message
    @unique_id = response.params['unique_id']
  end

  def test_certification_tok19_purchase_using_token_visa
    visa   = credit_card('4111111111111111', :month => 12, :year => 2017, :brand => 'visa', :verification_value => '101')
    assert response = @gateway.store(visa, @options)
    assert_success response

    @options[:order_id] = "TOK19"
    amount = 3400
    assert response = @gateway.purchase(amount, response.authorization, @options)
    assert_success response
    assert_equal "APPROVED", response.message
    @unique_id = response.params['unique_id']
  end

end
