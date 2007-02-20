require File.dirname(__FILE__) + '/../../test_helper'

class PsigateTest < Test::Unit::TestCase
  include ActiveMerchant::Billing
  
  def setup
    @gateway = PsigateGateway.new({
      :login => 'teststore',
      :password => 'psigate1234',
    })

    @creditcard = CreditCard.new({
      :number => '4111111111111111',
      :month => 8,
      :year => 2006,
      :first_name => 'Longbob',
      :last_name => 'Longsen'
    })
  end
  
  
  def test_authorize_success
    @creditcard.number = '1'
    
    assert response = @gateway.authorize(Money.us_dollar(2400), @creditcard, :order_id => 1)
    assert_equal Response, response.class
    assert_equal true, response.success?
  end
  
  def test_purchase_success    
    @creditcard.number = 1

    assert response = @gateway.purchase(Money.ca_dollar(2400), @creditcard, :order_id => 1)
    assert_equal Response, response.class
    assert_equal '#0001', response.params['receiptid']
    assert_equal true, response.success?
  end
  
  
  def test_purchase_error
     @creditcard.number = 2

     assert response = @gateway.purchase(Money.ca_dollar(2400), @creditcard, :order_id => 1)
     assert_equal Response, response.class
     assert_equal '#0001', response.params['receiptid']
     assert_equal false, response.success?
   end
   
   def test_purchase_exceptions
      @creditcard.number = 3 

      assert_raise(Error) do
        assert response = @gateway.purchase(Money.ca_dollar(100), @creditcard, :order_id => 1)    
      end
    end
    
    def test_amount_style   
     assert_equal '10.34', @gateway.send(:amount, Money.us_dollar(1034))
     assert_equal '10.34', @gateway.send(:amount, 1034)

     assert_raise(ArgumentError) do
       @gateway.send(:amount, '10.34')
     end
    end
end

class PsigateRequestTest < Test::Unit::TestCase
  include ActiveMerchant::Billing

  def setup
    @gateway = PsigateGateway.new({
      :login => 'teststore',
      :password => 'psigate1234',
    })
    
    @creditcard = CreditCard.new({
      :number => '4111111111111111',
      :month => 8,
      :year => 2007,
      :first_name => 'Longbob',
      :last_name => 'Longsen'
    })
    end

  def test_purchase_is_valid_xml
    parameters = @gateway.send(:parameters, Money.us_dollar(2000), @creditcard, {:order_id => 1004, 
      :billing_address => {
        :address1 => '123 fairweather Lane',
        :address2 => 'Apt B',
        :city => 'New York',
        :state => 'NY',
        :country => 'U.S.A.',
        :zip => '10010'},
      :email => 'jack@yahoo.com',
      :CardAction => 0 } )
    assert data = @gateway.send(:post_data,  parameters)
    assert REXML::Document.new(data)
    assert_equal xml_purchase_fixture.size, data.size
  end

  def test_capture_is_valid_xml
    parameters = @gateway.send(:parameters, Money.us_dollar(2000), CreditCard.new({}), {:order_id => 1004, 
      :CardAction => 2 } )

    assert data = @gateway.send(:post_data, parameters)
    assert REXML::Document.new(data)  
    assert_equal xml_capture_fixture.size, data.size
  end
  
  private

  def xml_purchase_fixture
    %q{<?xml version='1.0'?><Order><Bcity>New York</Bcity><OrderID>1004</OrderID><Bcountry>U.S.A.</Bcountry><CardAction>0</CardAction><Baddress1>123 fairweather Lane</Baddress1><StoreID>teststore</StoreID><Bprovince>NY</Bprovince><CardNumber>4111111111111111</CardNumber><PaymentType>CC</PaymentType><SubTotal>20.00</SubTotal><Passphrase>psigate1234</Passphrase><CardExpMonth>08</CardExpMonth><Baddress2>Apt B</Baddress2><Bpostalcode>10010</Bpostalcode><Bname>Longbob Longsen</Bname><CardExpYear>07</CardExpYear><Email>jack@yahoo.com</Email></Order>}
  end

  def xml_capture_fixture
    %q{<?xml version='1.0'?><Order><OrderID>1004</OrderID><CardAction>2</CardAction><StoreID>teststore</StoreID><PaymentType>CC</PaymentType><SubTotal>20.00</SubTotal><Passphrase>psigate1234</Passphrase></Order>}  
  end

end