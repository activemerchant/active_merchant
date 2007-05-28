require File.dirname(__FILE__) + '/../../test_helper'

class EwayTest < Test::Unit::TestCase
  def setup
    @gateway = EwayGateway.new(
      :login => '87654321'
    )

    @creditcard = credit_card('4646464646464646')
    
    @test_params_success = {
      :order_id => '1230123',
      :email => 'bob@testbob.com',
      :address => {
        :address1 => '1234 First St.',
        :address2 => 'Apt. 1',
        :city     => 'Melbourne',
        :state    => 'ACT',
        :country  => 'AU',
        :zip      => '12345'
      },
      :description => 'purchased items'
    }
   
    @xml_test_parameters = {
      :CustomerID => @test_params_success[:login],
      :CustomerInvoiceRef => @test_params_success[:order_id],
      :TotalAmount => 100,
      :CardNumber => @creditcard.number,
      :CardExpiryMonth => sprintf("%.2i", @creditcard.month),
      :CardExpiryYear => sprintf("%.4i", @creditcard.year)[-2..-1],
      :CustomerFirstName => @creditcard.first_name,
      :CustomerLastName => @creditcard.last_name,
      :CustomerEmail => @test_params_success[:email],
      :CustomerAddress => @test_params_success[:address][:address1],
      :CustomerPostcode => @test_params_success[:address][:zip],
      :CustomerInvoiceDescription => @test_params_success[:description],
      :CardHoldersName => @creditcard.name,
      :TrxnNumber => @test_params_success[:order_id],
      :Option1 => '',
      :Option2 => '',
      :Option3 => ''        
    }
  end

  def test_purchase_exceptions
    @creditcard.number = 3 
    
    assert_raise(Error) do
      assert response = @gateway.purchase(100, @creditcard, @test_params_success)    
    end
  end
       
  def test_amount_style
   assert_equal '1034', @gateway.send(:amount, 1034)
                                                      
   assert_raise(ArgumentError) do
     @gateway.send(:amount, '10.34')
   end
  end
  
  def test_purchase_is_valid_xml
   assert data = @gateway.send(:post_data, @xml_test_parameters)
   assert REXML::Document.new(data)
  end  

  def test_ensure_does_not_respond_to_authorize
    assert !@gateway.respond_to?(:authorize)
  end
  
  def test_ensure_does_not_respond_to_capture
    assert !@gateway.respond_to?(:capture)
  end
  
  def test_test_url_without_cvn
    assert_equal EwayGateway::TEST_URL, @gateway.send(:gateway_url, false, true)
  end
  
  def test_test_url_with_cvn
    assert_equal EwayGateway::TEST_CVN_URL, @gateway.send(:gateway_url, true, true)
  end
  
  def test_live_url_without_cvn
    assert_equal EwayGateway::LIVE_URL, @gateway.send(:gateway_url, false, false)
  end
  
  def test_live_url_with_cvn
    assert_equal EwayGateway::LIVE_CVN_URL, @gateway.send(:gateway_url, true, false)
  end
  
  def test_add_address
    post = {}
    @gateway.send(:add_address, post, @test_params_success)
    assert_equal '1234 First St., Apt. 1, Melbourne, ACT, AU', post[:CustomerAddress]
    assert_equal @test_params_success[:address][:zip], post[:CustomerPostcode]
  end

  private

  def xml_purchase_fixture
    %q{<ewaygateway><ewayCustomerID>87654321</ewayCustomerID><ewayOption3></ewayOption3><ewayCustomerFirstName>Longbob</ewayCustomerFirstName><ewayCustomerAddress>47 Bobway, Bobville, WA, Australia</ewayCustomerAddress><ewayCustomerInvoiceRef>1230123</ewayCustomerInvoiceRef><ewayCardHoldersName>Longbob Longsen</ewayCardHoldersName><ewayTotalAmount>100</ewayTotalAmount><ewayTrxnNumber>1230123</ewayTrxnNumber><ewayCustomerLastName>Longsen</ewayCustomerLastName><ewayCustomerPostcode>2000</ewayCustomerPostcode><ewayCardNumber>4646464646464646</ewayCardNumber><ewayOption1></ewayOption1><ewayCardExpiryMonth>08</ewayCardExpiryMonth><ewayOption2></ewayOption2><ewayCustomerEmail>bob@testbob.com</ewayCustomerEmail><ewayCustomerInvoiceDescription>purchased items</ewayCustomerInvoiceDescription><ewayCardExpiryYear>07</ewayCardExpiryYear></ewaygateway>}
  end
end


