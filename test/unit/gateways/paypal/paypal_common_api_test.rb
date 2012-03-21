require 'test_helper'
require 'nokogiri'

class PaypalExpressTest < Test::Unit::TestCase
  def setup
    @gateway = Class.new do 
      include PaypalCommonApi
      def currency; 'USD'; end
      def localized_amount(num); num; end
    end

    @address = { :address1 => '1234 My Street',
                 :address2 => 'Apt 1',
                 :company => 'Widgets Inc',
                 :city => 'Ottawa',
                 :state => 'ON',
                 :zip => 'K1C2N6',
                 :country => 'Canada',
                 :phone => '(555)555-5555'
               }
  end

  def xml_builder
    Builder::XmlMarkup.new
  end

  def wrap_xml(&block)
    REXML::Document.new(@gateway.send(:build_request_wrapper, 'Action', &block))
  end

  def test_add_payment_details_adds_express_only_payment_details_when_necessary
    options = {:express_request => true}
    @gateway.expects(:add_express_only_payment_details)
    @gateway.send(:add_payment_details, xml_builder, 100, 'USD', options)
  end

  def test_add_payment_details_adds_items_details
    options = {:items => [1]}
    @gateway.expects(:add_payment_details_items_xml)
    @gateway.send(:add_payment_details, xml_builder, 100, 'USD', options)
  end

  def test_add_payment_details_adds_address
    options = {:shipping_address => @address}
    @gateway.expects(:add_address)
    @gateway.send(:add_payment_details, xml_builder, 100, 'USD', options)
  end

  def test_add_payment_details_adds_items_details_elements
    options = {:items => [{:name => 'foo'}]}
    request = wrap_xml do |xml|
      @gateway.send(:add_payment_details, xml, 100, 'USD', options)
    end
    assert_equal 'foo', REXML::XPath.first(request, '//n2:PaymentDetails/n2:PaymentDetailsItem/n2:Name').text
  end

  def test_add_express_only_payment_details_adds_non_blank_fields
    request = wrap_xml do |xml|
      @gateway.send(:add_express_only_payment_details, xml, {:payment_action => 'Sale', :payment_request_id => ''})
    end
    assert_equal 'Sale', REXML::XPath.first(request, '//n2:PaymentAction').text
    assert_nil REXML::XPath.first(request, '//n2:PaymentRequestID')
  end

  def test_build_request_wrapper_plain
    result = @gateway.send(:build_request_wrapper, 'Action') do |xml|
      xml.tag! 'foo', 'bar'
    end
    assert_equal 'bar', REXML::XPath.first(REXML::Document.new(result), '//ActionReq/ActionRequest/foo').text
  end

  def test_build_request_wrapper_with_request_details
    result = @gateway.send(:build_request_wrapper, 'Action', :request_details => true) do |xml|
       xml.tag! 'n2:TransactionID', 'baz'
    end
    assert_equal 'baz', REXML::XPath.first(REXML::Document.new(result), '//ActionReq/ActionRequest/n2:ActionRequestDetails/n2:TransactionID').text
  end

  def test_build_get_transaction_details
    request = REXML::Document.new(@gateway.send(:build_get_transaction_details, '123'))
    assert_equal '123', REXML::XPath.first(request, '//GetTransactionDetailsReq/GetTransactionDetailsRequest/TransactionID').text
  end

  def test_build_get_balance
    request = REXML::Document.new(@gateway.send(:build_get_balance, '1'))
    assert_equal '1', REXML::XPath.first(request, '//GetBalanceReq/GetBalanceRequest/ReturnAllCurrencies').text
  end

  def test_transaction_search_requires
    assert_raise ArgumentError do
      @gateway.transaction_search()
    end
  end
  def test_build_transaction_search_request
    options = {:start_date => Date.strptime('02/21/2012', '%m/%d/%Y'),
      :end_date => Date.strptime('03/21/2012', '%m/%d/%Y'),
      :receiver => 'foo@example.com',
      :first_name => 'Robert'}
    request = REXML::Document.new(@gateway.send(:build_transaction_search, options))
    assert_equal '2012-02-21T05:00:00Z', REXML::XPath.first(request, '//TransactionSearchReq/TransactionSearchRequest/StartDate').text
    assert_equal '2012-03-21T04:00:00Z', REXML::XPath.first(request, '//TransactionSearchReq/TransactionSearchRequest/EndDate').text
    assert_equal 'foo@example.com', REXML::XPath.first(request, '//TransactionSearchReq/TransactionSearchRequest/Receiver').text
  end

  def test_build_do_authorize_request
    request = REXML::Document.new(@gateway.send(:build_do_authorize,123, 100, :currency => 'USD'))
    assert_equal '123', REXML::XPath.first(request, '//DoAuthorizationReq/DoAuthorizationRequest/TransactionID').text
    assert_equal '1.00', REXML::XPath.first(request, '//DoAuthorizationReq/DoAuthorizationRequest/Amount').text
  end

  
  def test_build_manage_pending_transaction_status_request
    request = REXML::Document.new(@gateway.send(:build_manage_pending_transaction_status,123, 'Accept'))
    assert_equal '123', REXML::XPath.first(request, '//ManagePendingTransactionStatusReq/ManagePendingTransactionStatusRequest/TransactionID').text
    assert_equal 'Accept', REXML::XPath.first(request, '//ManagePendingTransactionStatusReq/ManagePendingTransactionStatusRequest/Action').text
  end

end
