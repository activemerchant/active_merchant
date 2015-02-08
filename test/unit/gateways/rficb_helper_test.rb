class RficbHelperTest < Test::Unit::TestCase
  include OffsitePayments::Integrations

  def setup
    @helper = Rficb::Helper.new 123,'some_key',
    :amount => 500,
    :transaction_type => 'wmr',
    :credential2 => 'Some product',
    :credential3 => 'Some comments',
    :credential4 => '1'
  end

  def test_basic_helper_fields
    assert_field 'order_id', '123'
    assert_field 'key', 'some_key'
    assert_field 'cost', '500'
    assert_field 'name', 'Some product'
    assert_field 'comment', 'Some comments'
  end

  def test_customer_fields
    @helper.customer :email => 'some_email@mail.com', :phone => '123345123'
    assert_field 'email', 'some_email@mail.com'
    assert_field 'phone_number', '123345123'
  end
end
