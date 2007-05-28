require File.dirname(__FILE__) + '/../test_helper'

class RemoteQuickpayTest < Test::Unit::TestCase

  # Quickpay MerchantId
  LOGIN = 'MERCHANTID'
  
  # Quickpay md5checkword
  PASSWORD = 'CHECKWORD'
  
  # 100 cents
  AMOUNT = 100
  
  def setup
  
    @gateway = QuickpayGateway.new(
      :login => LOGIN,
      :password => PASSWORD
    )
    
    @declined_visa = CreditCard.new(
      :number => '4000300011112220',
      :month => 9,
      :year => Time.now.year + 1,
      :first_name => 'Longbob',
      :last_name => 'Longsen'
    )
    
    @visa           = credit_card('4000100011112224')
    @dankort        = credit_card('5019717010103742')
    @visa_dankort   = credit_card('4571100000000000')
    @electron_dk    = credit_card('4175001000000000')
    @diners_club    = credit_card('30401000000000')
    @diners_club_dk = credit_card('36148010000000')
    @maestro        = credit_card('5020100000000000')
    @maestro_dk     = credit_card('6769271000000000')
    @mastercard_dk  = credit_card('5413031000000000')
    @amex_dk        = credit_card('3747100000000000')
    @amex           = credit_card('3700100000000000')
    
    # forbrugsforeningen doesn't use a verification value
    @forbrugsforeningen = credit_card('6007221000000000', :verification_value => nil)
  end
  
  def test_successful_purchase
    assert response = @gateway.purchase(AMOUNT, @visa, :order_id => generate_order_id)
    assert_equal 'OK', response.message
    assert_equal 'DKK', response.params['currency']
    assert response.success?
    assert !response.authorization.blank?
  end
  
  def test_successful_usd_purchase
    assert response = @gateway.purchase(AMOUNT, @visa, :order_id => generate_order_id, :currency => 'USD')
    assert_equal 'OK', response.message
    assert_equal 'USD', response.params['currency']
    assert response.success?
    assert !response.authorization.blank?
  end
  
  def test_dankort_authorization
    assert response = @gateway.authorize(AMOUNT, @dankort, :order_id => generate_order_id)
    assert response.success?
    assert !response.authorization.blank?
    assert_equal 'Dankort', response.params['cardtype']
  end
  
  def test_visa_dankort_authorization
    assert response = @gateway.authorize(AMOUNT, @visa_dankort, :order_id => generate_order_id)
    assert response.success?
    assert !response.authorization.blank?
    assert_equal 'Visa-Dankort', response.params['cardtype']
  end
  
  def test_visa_electron_authorization
    assert response = @gateway.authorize(AMOUNT, @electron_dk, :order_id => generate_order_id)
    assert response.success?
    assert !response.authorization.blank?
    assert_equal 'Visa-Electron-DK', response.params['cardtype']
  end
  
  def test_diners_club_authorization
    assert response = @gateway.authorize(AMOUNT, @diners_club, :order_id => generate_order_id)
    assert response.success?
    assert !response.authorization.blank?
    assert_equal 'Diners', response.params['cardtype']
  end
  
  def test_diners_club_dk_authorization
    assert response = @gateway.authorize(AMOUNT, @diners_club_dk, :order_id => generate_order_id)
    assert response.success?
    assert !response.authorization.blank?
    assert_equal 'Diners', response.params['cardtype']
  end
  
  def test_maestro_authorization
    assert response = @gateway.authorize(AMOUNT, @maestro, :order_id => generate_order_id)
    assert response.success?
    assert !response.authorization.blank?
    assert_equal 'Maestro', response.params['cardtype']
  end
  
  def test_maestro_dk_authorization
    assert response = @gateway.authorize(AMOUNT, @maestro_dk, :order_id => generate_order_id)
    assert response.success?
    assert !response.authorization.blank?
    assert_equal 'Maestro', response.params['cardtype']
  end
  
  def test_mastercard_dk_authorization
    assert response = @gateway.authorize(AMOUNT, @mastercard_dk, :order_id => generate_order_id)
    assert response.success?
    assert !response.authorization.blank?
    assert_equal 'MasterCard-DK', response.params['cardtype']
  end
  
  def test_american_express_dk_authorization
    assert response = @gateway.authorize(AMOUNT, @amex_dk, :order_id => generate_order_id)
    assert response.success?
    assert !response.authorization.blank?
    assert_equal 'AmericanExpress-DK', response.params['cardtype']
  end

  def test_american_express_authorization
    assert response = @gateway.authorize(AMOUNT, @amex, :order_id => generate_order_id)
    assert response.success?
    assert !response.authorization.blank?
    assert_equal 'AmericanExpress', response.params['cardtype']
  end
  
  def test_forbrugsforeningen_authorization
    assert response = @gateway.authorize(AMOUNT, @forbrugsforeningen, :order_id => generate_order_id)
    assert response.success?
    assert !response.authorization.blank?
    assert_equal 'FBG-1886', response.params['cardtype']
  end
  
  def test_unsuccessful_purchase_with_missing_cvv2
    assert response = @gateway.purchase(AMOUNT, @declined_visa, :order_id => generate_order_id)
    assert_equal 'Missing/error in card verification data', response.message
    assert !response.success?
    assert response.authorization.blank?
  end

  def test_authorize_and_capture
    amount = AMOUNT
    assert auth = @gateway.authorize(amount, @visa, :order_id => generate_order_id)
    assert auth.success?
    assert_equal 'OK', auth.message
    assert auth.authorization
    assert capture = @gateway.capture(amount, auth.authorization)
    assert capture.success?
    assert_equal 'OK', capture.message
  end

  def test_failed_capture
    assert response = @gateway.capture(AMOUNT, '')
    assert !response.success?
    assert_equal 'Missing/error in transaction number', response.message
  end
  
  def test_purchase_and_void
    assert auth = @gateway.authorize(AMOUNT, @visa, :order_id => generate_order_id)
    assert auth.success?
    assert_equal 'OK', auth.message
    assert auth.authorization
    assert void = @gateway.void(auth.authorization)
    assert void.success?
    assert_equal 'OK', void.message
  end
  
  def test_authorization_capture_and_credit
    assert auth = @gateway.authorize(AMOUNT, @visa, :order_id => generate_order_id)
    assert auth.success?
    assert capture = @gateway.capture(AMOUNT, auth.authorization)
    assert capture.success?
    assert credit = @gateway.credit(AMOUNT, auth.authorization)
    assert credit.success?
    assert_equal 'OK', credit.message
  end
  
  def test_purchase_and_credit
    assert purchase = @gateway.purchase(AMOUNT, @visa, :order_id => generate_order_id)
    assert purchase.success?
    assert credit = @gateway.credit(AMOUNT, purchase.authorization)
    assert credit.success?
  end

  def test_invalid_login
    gateway = QuickpayGateway.new(
        :login => '',
        :password => ''
    )
    assert response = gateway.purchase(AMOUNT, @visa, :order_id => generate_order_id)
    assert_equal 'Missing/error in merchant', response.message
    assert !response.success?
  end
end
