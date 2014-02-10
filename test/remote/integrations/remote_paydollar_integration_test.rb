require 'test_helper'

class RemotePaydollarIntegrationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def test_known_reference
    assert Paydollar.return(known_valid_query_string, fixtures(:paydollar)).success?
  end

  private
  def known_valid_query_string
    'Ref=4'
  end

end