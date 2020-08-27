require 'test_helper'

class RemoteTwoCTwoPTest < Test::Unit::TestCase
  def setup
    @gateway = TwoCTwoPGateway.new(fixtures(:two_c_two_p))

    @amount = 100
    @credit_card = credit_card('4000100011112224')
    @declined_card = credit_card('4000300011112220')

    @invalid_card_options = {
      order_id: generate_unique_id,
      description: 'Store Purchase',
      currency: 'SGD',
      pan_country: 'SG',
      enc_card_data: '00acTPCs4oy2P52nolDsjc9FabG5/p6OqMzISvh8glP+qb5YgD7z7wCayBp9QW66CtAFENvqW/zZTgDBSKM8qz0W6sFx4TO6Uww58ar//VvDc5+OUz+JIAlQCPhewZN8IznxlyaBFvFLpvi+VugaUWo/Eow6kYalVuIj0MYg8OAccgU=U2FsdGVkX18jR/eUn9PmDT3MSuD3cmgWSovAztlaIPaE52l+fl3SJkU2+UhgJxZL'
    }

    @valid_card_options = {
      order_id: generate_unique_id,
      description: 'Store Purchase',
      currency: 'SGD',
      pan_country: 'SG',
      enc_card_data: '00acFe0r2bVCCb/5WDv9HnihztQCe1CJEzxEcbRye7CaKIdijUs1e1TWJutQJEmXeKnPe4KPCBxUYVCeO2StyzgSbKusXbCuXCmek7zF36tVYf3uyz17UunzvPVyEAAmigHHGixQ6e8FcsOzLy0iXaIGakw48H3So55Ye39x300vBQA=U2FsdGVkX18G2koigXeLNyKai2YUUrED986iyxA4RRd5fstCRZYa8TMrqrtyPSKc'
    }    
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @valid_card_options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_fail_purchase
    response = @gateway.purchase(@amount, @credit_card, @invalid_card_options)
    assert_failure response
    assert_equal 'Invalid Card Number.', response.message
  end
end
