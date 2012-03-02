require 'test_helper'


class RemoteLitleTest < Test::Unit::TestCase
  def setup
    @gateway = LitleGateway.new
    @amount = 10010
    @credit_card =  CreditCard.new(
    :first_name => 'John',
    :last_name  => 'Smith',
    :month      => '01',
    :year       => '2012',
    :type       => 'visa',
    :number     => '4457010000000009',
    :verification_value => '349'
    )

    order_id = '1'
    ip = '192.168.0.1'
    customer = ''
    merchant = 'Default Report Group'
    description = 'cool stuff'
    email = 'abc@xyz.com'
    currency = 'USD'
    invoice = '123543'

    billing_address = {
      :name      => 'John Smith',
      :company   => 'testCompany',
      :address1  => '1 Main St.',
      :city      => 'Burlington',
      :state     => 'MA',
      :country   => 'USA',
      :zip       => '01803-3747',
      :phone     => '1234567890'
    }

    shipping_address = {
      :name      => 'John Smith',
      :company   => '',
      :address1  => '1 Main St.',
      :city      => 'Burlington',
      :state     => 'MA',
      :country   => 'USA',
      :zip       => '01803-3747',
      :phone     => '1234567890'
    }

    @options = {
      :order_id=>order_id,
      :ip=>ip,
      :customer=>customer,
      :invoice=>invoice,
      :merchant=>merchant,
      :description=>description,
      :email=>email,
      :currency=>currency,
      :billing_address=>billing_address,
      :shipping_address=>shipping_address,
      :merchant_id=>'101',
      :user=>'PHXMLTEST',
      :password=>'nosuchpassword',
      :version=>'8.10',
      :url=>'https://www.testlitle.com/sandbox/communicator/online',
      :proxy_addr=>'smoothproxy',
      :proxy_port=>'8080',
      :report_group=>'Default Report Group'
    }

  end

  def test_successful_authorization
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Approved', response.message
    assert response.authorization
  end
  
  def test_authorization_and_capture
    assert authorization = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorization

    assert capture = @gateway.capture(@amount, authorization.authorization, @options)
    assert_success capture
    assert_equal 'Approved', capture.message
  end
end
