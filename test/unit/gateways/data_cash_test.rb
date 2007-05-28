require File.dirname(__FILE__) + '/../../test_helper'

class DataCashTest < Test::Unit::TestCase
  # 100 Cents
  AMOUNT = 100

  def setup
    @gateway = DataCashGateway.new(
      :login => 'LOGIN',
      :password => 'PASSWORD'
    )

    @creditcard = credit_card('4242424242424242')
  end
  
  def test_supported_countries
    assert_equal ['GB'], DataCashGateway.supported_countries
  end
  
  def test_supported_card_types
    assert_equal [ :visa, :master, :american_express, :discover, :diners_club, :jcb, :maestro, :switch, :solo, :laser ], DataCashGateway.supported_cardtypes
  end
end