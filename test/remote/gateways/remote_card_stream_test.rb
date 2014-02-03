require 'test_helper'

class RemoteCardStreamTest < Test::Unit::TestCase
  def setup
    Base.mode = :test

    @gateway = CardStreamGateway.new(fixtures(:card_stream))

    @amex = credit_card('374245455400001',
      :month => '12',
      :year => '2014',
      :verification_value => '4887',
      :brand => :american_express
    )

    @uk_maestro = credit_card('6759015050123445002',
      :month => '12',
      :year => '2014',
      :issue_number => '0',
      :verification_value => '309',
      :brand => :switch
    )

    @mastercard = credit_card('5301250070000191',
      :month => '12',
      :year => '2014',
      :verification_value => '419',
      :brand => :master
    )

    @visacreditcard = credit_card('4929421234600821',
    :month => '12',
    :year => '2014',
    :verification_value => '356',
    :brand => :visa
    )

    @visadebitcard = credit_card('4539791001730106',
      :month => '12',
      :year => '2014',
      :verification_value => '289',
      :brand => :visa
    )

    @declined_card = credit_card('4000300011112220',
      :month => '9',
      :year => '2014'
    )

    @amex_options = {
      :billing_address => {
        :address1 => 'The Hunts Way',
        :city => "",
        :state => "Leicester",
        :zip => 'SO18 1GW'
      },
      :order_id => generate_unique_id,
      :description => 'AM test purchase'
    }

    @visacredit_options = {
      :billing_address => {
        :address1 => "Flat 6, Primrose Rise",
        :address2 => "347 Lavender Road",
        :city => "",
        :state => "Northampton",
        :zip => 'NN17 8YG '
      },
      :order_id => generate_unique_id,
      :description => 'AM test purchase'
    }

    @visadebit_options = {
      :billing_address => {
        :address1 => 'Unit 5, Pickwick Walk',
        :address2 => "120 Uxbridge Road",
        :city => "Hatch End",
        :state => "Middlesex",
        :zip => "HA6 7HJ"
      },
      :order_id => generate_unique_id,
      :description => 'AM test purchase'
    }

    @mastercard_options = {
      :billing_address => {
        :address1 => '25 The Larches',
        :city => "Narborough",
        :state => "Leicester",
        :zip => 'LE10 2RT'
      },
      :order_id => generate_unique_id,
      :description => 'AM test purchase'
    }

    @uk_maestro_options = {
      :billing_address => {
        :address1 => 'The Parkway',
        :address2 => "5258 Larches Approach",
        :city => "Hull",
        :state => "North Humberside",
        :zip => 'HU10 5OP'
      },
      :order_id => generate_unique_id,
      :description => 'AM test purchase'
    }
  end

  def test_successful_visacreditcard_authorization_and_capture
    assert responseAuthorization = @gateway.authorize(142, @visacreditcard, @visacredit_options)
    assert_equal 'APPROVED', responseAuthorization.message
    assert_success responseAuthorization
    assert responseAuthorization.test?
    assert !responseAuthorization.authorization.blank?
    assert responseCapture = @gateway.capture(142, responseAuthorization.authorization, @visacredit_options)
    assert_equal 'APPROVED', responseCapture.message
    assert_success responseCapture
    assert responseCapture.test?
  end

  def test_successful_visacreditcard_authorization_and_refund
    assert responseAuthorization = @gateway.authorize(284, @visacreditcard, @visacredit_options)
    assert_equal 'APPROVED', responseAuthorization.message
    assert_success responseAuthorization
    assert responseAuthorization.test?
    assert !responseAuthorization.authorization.blank?
    assert responseRefund = @gateway.refund(142, responseAuthorization.authorization, @visacredit_options)
    assert_equal 'APPROVED', responseRefund.message
    assert_success responseRefund
    assert responseRefund.test?
  end

  def test_successful_visacreditcard_authorization_and_void
    assert responseAuthorization = @gateway.authorize(284, @visacreditcard, @visacredit_options)
    assert_equal 'APPROVED', responseAuthorization.message
    assert_success responseAuthorization
    assert responseAuthorization.test?
    assert !responseAuthorization.authorization.blank?
    assert responseRefund = @gateway.void(responseAuthorization.authorization, @visacredit_options)
    assert_equal 'APPROVED', responseRefund.message
    assert_success responseRefund
    assert responseRefund.test?
  end

  def test_successful_visadebitcard_authorization_and_capture
    assert responseAuthorization = @gateway.authorize(142, @visadebitcard, @visadebit_options)
    assert_equal 'APPROVED', responseAuthorization.message
    assert_success responseAuthorization
    assert responseAuthorization.test?
    assert !responseAuthorization.authorization.blank?
    assert responseCapture = @gateway.capture(142, responseAuthorization.authorization, @visadebit_options)
    assert_equal 'APPROVED', responseCapture.message
    assert_success responseCapture
    assert responseCapture.test?
  end

  def test_successful_visadebitcard_authorization_and_refund
    assert responseAuthorization = @gateway.authorize(284, @visadebitcard, @visadebit_options)
    assert_equal 'APPROVED', responseAuthorization.message
    assert_success responseAuthorization
    assert responseAuthorization.test?
    assert !responseAuthorization.authorization.blank?
    assert responseRefund = @gateway.refund(142, responseAuthorization.authorization, @visadebit_options)
    assert_equal 'APPROVED', responseRefund.message
    assert_success responseRefund
    assert responseRefund.test?
  end

  def test_successful_amex_authorization_and_capture
    assert responseAuthorization = @gateway.authorize(142, @amex, @amex_options)
    assert_equal 'APPROVED', responseAuthorization.message
    assert_success responseAuthorization
    assert responseAuthorization.test?
    assert !responseAuthorization.authorization.blank?
    assert responseCapture = @gateway.capture(142, responseAuthorization.authorization, @amex_options)
    assert_equal 'APPROVED', responseCapture.message
    assert_success responseCapture
    assert responseCapture.test?
  end

  def test_successful_amex_authorization_and_refund
    assert responseAuthorization = @gateway.authorize(284, @amex, @amex_options)
    assert_equal 'APPROVED', responseAuthorization.message
    assert_success responseAuthorization
    assert responseAuthorization.test?
    assert !responseAuthorization.authorization.blank?
    assert responseRefund = @gateway.refund(142, responseAuthorization.authorization, @amex_options)
    assert_equal 'APPROVED', responseRefund.message
    assert_success responseRefund
    assert responseRefund.test?
  end

  def test_successful_mastercard_authorization_and_capture
    assert responseAuthorization = @gateway.authorize(142, @mastercard, @mastercard_options)
    assert_equal 'APPROVED', responseAuthorization.message
    assert_success responseAuthorization
    assert responseAuthorization.test?
    assert !responseAuthorization.authorization.blank?
    assert responseCapture = @gateway.capture(142, responseAuthorization.authorization, @mastercard_options)
    assert_equal 'APPROVED', responseCapture.message
    assert_success responseCapture
    assert responseCapture.test?
  end

  def test_successful_mastercard_authorization_and_refund
    assert responseAuthorization = @gateway.authorize(284, @mastercard, @mastercard_options)
    assert_equal 'APPROVED', responseAuthorization.message
    assert_success responseAuthorization
    assert responseAuthorization.test?
    assert !responseAuthorization.authorization.blank?
    assert responseRefund = @gateway.refund(142, responseAuthorization.authorization, @mastercard_options)
    assert_equal 'APPROVED', responseRefund.message
    assert_success responseRefund
    assert responseRefund.test?
  end

  def test_successful_visacreditcard_purchase
    assert response = @gateway.purchase(142, @visacreditcard, @visacredit_options)
    assert_equal 'APPROVED', response.message
    assert_success response
    assert response.test?
    assert !response.authorization.blank?
  end

  def test_successful_visadebitcard_purchase
    assert response = @gateway.purchase(142, @visadebitcard, @visadebit_options)
    assert_equal 'APPROVED', response.message
    assert_success response
    assert response.test?
    assert !response.authorization.blank?
  end

  def test_successful_mastercard_purchase
    assert response = @gateway.purchase(142, @mastercard, @mastercard_options)
    assert_equal 'APPROVED', response.message
    assert_success response
    assert response.test?
    assert !response.authorization.blank?
  end

  def test_declined_mastercard_purchase
    assert response = @gateway.purchase(10000, @mastercard, @mastercard_options)
    assert_equal 'CARD DECLINED', response.message
    assert_failure response
    assert response.test?
  end

  def test_expired_mastercard
    @mastercard.year = 2012
    assert response = @gateway.purchase(142, @mastercard, @mastercard_options)
    assert_equal 'CARD EXPIRED', response.message
    assert_failure response
    assert response.test?
  end

  def test_successful_maestro_purchase
    assert response = @gateway.purchase(142, @uk_maestro, @uk_maestro_options)
    assert_equal 'APPROVED', response.message
    assert_success response
  end

  def test_successful_amex_purchase
    assert response = @gateway.purchase(142, @amex, @amex_options)
    assert_equal 'APPROVED', response.message
    assert_success response
    assert response.test?
    assert !response.authorization.blank?
  end

  def test_invalid_login
    gateway = CardStreamGateway.new(
      :login => '',
      :shared_secret => ''
    )
    assert response = gateway.purchase(142, @mastercard, @mastercard_options)
    assert_equal 'MISSING MERCHANTID', response.message
    assert_failure response
  end

  def test_usd_merchant_currency
    assert response = @gateway.purchase(142, @mastercard, @mastercard_options.update(:currency => 'USD'))
    assert_equal 'APPROVED', response.message
    assert_success response
    assert response.test?
  end
end
