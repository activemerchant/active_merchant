require 'test_helper'

class AuthorizeNetPaymentNonceTest < Test::Unit::TestCase
  def setup
    @token = tokenized_credit_card
  end

  def test_type
    assert_equal 'tokenized', @token.type
  end
end
