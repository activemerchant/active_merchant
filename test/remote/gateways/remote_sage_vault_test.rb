require 'test_helper'

class RemoteSageVaultTest < Test::Unit::TestCase

  def setup
    @gateway = SageVaultGateway.new(fixtures(:sage))

    @visa        = credit_card("4111111111111111")
    @mastercard  = credit_card("5499740000000057")
    @discover    = credit_card("6011000993026909")
    @amex        = credit_card("371449635392376")

    @declined_card = credit_card('4000')

    @options = { }
  end

  def test_store_visa
    assert response = @gateway.store(@visa, @options)
    assert_success response
    assert auth = response.authorization,
      "Store card authorization should not be nil"
    assert_not_nil response.message
  end

  def test_failed_store
    assert response = @gateway.store(@declined_card, @options)
    assert_failure response
    assert_nil response.authorization
  end

  def test_unstore_visa
    assert auth = @gateway.store(@visa, @options).authorization,
      "Unstore card authorization should not be nil"
    assert response = @gateway.unstore(auth, @options)
    assert_success response
  end

  def test_failed_unstore_visa
    assert auth = @gateway.store(@visa, @options).authorization,
      "Unstore card authorization should not be nil"
    assert response = @gateway.unstore(auth, @options)
    assert_success response
  end

end
