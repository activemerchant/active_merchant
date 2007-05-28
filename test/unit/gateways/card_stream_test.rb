require File.dirname(__FILE__) + '/../../test_helper'

class CardStreamTest < Test::Unit::TestCase
  # 100 Cents
  AMOUNT = 100

  def setup
    @gateway = CardStreamGateway.new(
      :login => 'LOGIN',
      :password => 'PASSWORD'
    )

    @creditcard = credit_card('4242424242424242')
  end
  
  def test_supported_countries
    assert_equal ['GB'], CardStreamGateway.supported_countries
  end
  
  def test_supported_card_types
    assert_equal [:visa, :master, :american_express, :discover, :jcb, :maestro, :solo, :switch], CardStreamGateway.supported_cardtypes
  end
  
  def test_default_currency
    params = {}
    
    @gateway.send(:add_amount, params, 1000, {})
    assert_equal '826', params[:CurrencyCode]
  end
  
  def test_override_currency
    params = {}
    
    @gateway.send(:add_amount, params, 1000, :currency => 'USD')
    assert_equal '840', params[:CurrencyCode]
  end
end