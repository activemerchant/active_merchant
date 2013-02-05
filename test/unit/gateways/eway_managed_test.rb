require 'test_helper'

class EwayManagedTest < Test::Unit::TestCase
  def setup
    Base.gateway_mode = :test

    @gateway = EwayManagedGateway.new(:username => 'username', :login => 'login', :password => 'password')

    @valid_card='4444333322221111'
    @valid_customer_id='9876543211000'

    @credit_card = credit_card(@valid_card)
    @declined_card = credit_card('4444111111111111')

    @amount = 100

    @options = { :billing_address => {
                  :address1 => '1234 My Street',
                  :address2 => 'Apt 1',
                  :company => 'Widgets Inc',
                  :city => 'Ottawa',
                  :state => 'ON',
                  :zip => 'K1C2N6',
                  :country => 'au',
                  :title => 'Mr.',
                  :phone => '(555)555-5555'
               },
               :email => 'someguy1232@fakeemail.net',
               :order_id => '1000',
               :customer => 'mycustomerref',
               :description => 'My Description',
               :invoice => 'invoice-4567'
    }
  end

  def test_should_require_billing_address_on_store
    assert_raise ArgumentError do
      @gateway.store(@credit_card, { })
    end
    assert_raise ArgumentError do
      @gateway.store(@credit_card, { :billing_address => {} })
    end
    assert_raise ArgumentError do
      @gateway.store(@credit_card, { :billing_address => { :title => 'Mr.' } })
    end
    assert_raise ArgumentError do
      @gateway.store(@credit_card, { :billing_address => { :country => 'au' } })
    end
    assert_nothing_raised do
      @gateway.expects(:ssl_post).returns(successful_store_response)
      @gateway.store(@credit_card, { :billing_address => { :title => 'Mr.', :country => 'au' } })
    end
  end

  def test_should_require_billing_address_on_update
    assert_raise ArgumentError do
      @gateway.update(@valid_customer_id, @credit_card, { })
    end
    assert_raise ArgumentError do
      @gateway.update(@valid_customer_id, @credit_card, { :billing_address => {} })
    end
    assert_raise ArgumentError do
      @gateway.update(@valid_customer_id, @credit_card, { :billing_address => { :title => 'Mr.' } })
    end
    assert_raise ArgumentError do
      @gateway.update(@valid_customer_id, @credit_card, { :billing_address => { :country => 'au' } })
    end
    assert_nothing_raised do
      @gateway.expects(:ssl_post).returns(successful_update_response)
      @gateway.update(@valid_customer_id, @credit_card, { :billing_address => { :title => 'Mr.', :country => 'au' } })
    end
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @valid_customer_id, @options)
    assert_instance_of EwayManagedGateway::EwayResponse, response
    assert_equal "00,Transaction Approved(Test Gateway)", response.message
    assert_success response
    assert_equal "123456", response.authorization
    assert_equal "123456", response.params['transaction_number']
    assert response.test?
  end

  def test_expected_request_on_purchase
    @gateway.expects(:ssl_post).with { |endpoint, data, headers|
      # Compare the actual and expected XML documents, by converting them to Hashes first
      expected = Hash.from_xml(expected_purchase_request)
      actual = Hash.from_xml(data)
      expected == actual
    }.returns(successful_purchase_response)
    @gateway.purchase(@amount, @valid_customer_id, @options)
  end

  def test_purchase_invoice_reference_comes_from_order_id_or_invoice
    options = @options.dup

    # invoiceReference == options[:order_id]
    options[:order_id] = 'order_id'
    options.delete(:invoice)

    @gateway.expects(:ssl_post).with { |endpoint, data, headers|
      request_hash = Hash.from_xml(data)
      request_hash['Envelope']['Body']['ProcessPayment']['invoiceReference'] == 'order_id'
    }.returns(successful_purchase_response)
    @gateway.purchase(@amount, @valid_customer_id, options)

    # invoiceReference == options[:invoice]
    options[:invoice] = 'invoice'
    options.delete(:order_id)

    @gateway.expects(:ssl_post).with { |endpoint, data, headers|
      request_hash = Hash.from_xml(data)
      request_hash['Envelope']['Body']['ProcessPayment']['invoiceReference'] == 'invoice'
    }.returns(successful_purchase_response)
    @gateway.purchase(@amount, @valid_customer_id, options)

    # invoiceReference == options[:order_id] || options[:invoice]
    options[:order_id] = 'order_id'
    options[:invoice] = 'invoice'

    @gateway.expects(:ssl_post).with { |endpoint, data, headers|
      request_hash = Hash.from_xml(data)
      request_hash['Envelope']['Body']['ProcessPayment']['invoiceReference'] == 'order_id'
    }.returns(successful_purchase_response)
    @gateway.purchase(@amount, @valid_customer_id, options)

  end

  def test_invalid_customer_id
    @gateway.expects(:ssl_post).returns(unsuccessful_authorization_response)

    assert response = @gateway.purchase(@amount, '1', @options)
    assert_instance_of EwayManagedGateway::EwayResponse, response
    assert_failure response
  end

  def test_successful_store
    @gateway.expects(:ssl_post).returns(successful_store_response)

    assert response = @gateway.store(@credit_card, @options)
    assert_instance_of EwayManagedGateway::EwayResponse, response
    assert_equal "OK", response.message
    assert_success response
    assert_equal "1234567", response.token
    assert response.test?
  end

  def test_expected_request_on_store
    @gateway.expects(:ssl_post).with { |endpoint, data, headers|
      # Compare the actual and expected XML documents, by converting them to Hashes first
      expected = Hash.from_xml(expected_store_request)
      actual = Hash.from_xml(data)
      expected == actual
    }.returns(successful_store_response)
    @gateway.store(@credit_card, @options)
  end

  def test_email_on_store_may_come_from_options_root_or_billing_address
    options = @options.dup

    # Legacy Behavior
    options.delete(:email)
    options[:billing_address][:email] = 'email+billing@example.com'

    @gateway.expects(:ssl_post).with { |endpoint, data, headers|
      request_hash = Hash.from_xml(data)
      request_hash['Envelope']['Body']['CreateCustomer']['Email'] == 'email+billing@example.com'
    }.returns(successful_store_response)
    @gateway.store(@credit_card, options)

    # Desired Behavior
    options[:billing_address].delete(:email)
    options[:email] = 'email+root@example.com'

    @gateway.expects(:ssl_post).with { |endpoint, data, headers|
      request_hash = Hash.from_xml(data)
      request_hash['Envelope']['Body']['CreateCustomer']['Email'] == 'email+root@example.com'
    }.returns(successful_store_response)
    @gateway.store(@credit_card, options)

    # Precedence given to billing address when email is in both hashes (to support legacy behavior)
    options[:billing_address][:email] = 'email+billing@example.com'
    options[:email] = 'email+root@example.com'

    @gateway.expects(:ssl_post).with { |endpoint, data, headers|
      request_hash = Hash.from_xml(data)
      request_hash['Envelope']['Body']['CreateCustomer']['Email'] == 'email+billing@example.com'
    }.returns(successful_store_response)
    @gateway.store(@credit_card, options)
  end

  def test_customer_ref_on_store_may_come_from_options_root_or_billing_address
    options = @options.dup

    # Legacy Behavior
    options.delete(:customer)
    options[:billing_address][:customer_ref] = 'customer_ref+billing'

    @gateway.expects(:ssl_post).with { |endpoint, data, headers|
      request_hash = Hash.from_xml(data)
      request_hash['Envelope']['Body']['CreateCustomer']['CustomerRef'] == 'customer_ref+billing'
    }.returns(successful_store_response)
    @gateway.store(@credit_card, options)

    # Desired Behavior
    options[:billing_address].delete(:customer_ref)
    options[:customer] = 'customer_ref+root'

    @gateway.expects(:ssl_post).with { |endpoint, data, headers|
      request_hash = Hash.from_xml(data)
      request_hash['Envelope']['Body']['CreateCustomer']['CustomerRef'] == 'customer_ref+root'
    }.returns(successful_store_response)
    @gateway.store(@credit_card, options)

    # Precedence given to billing address when customer_ref is in both hashes (to support legacy behavior)
    options[:billing_address][:customer_ref] = 'customer_ref+billing'
    options[:customer] = 'customer_ref+root'

    @gateway.expects(:ssl_post).with { |endpoint, data, headers|
      request_hash = Hash.from_xml(data)
      request_hash['Envelope']['Body']['CreateCustomer']['CustomerRef'] == 'customer_ref+billing'
    }.returns(successful_store_response)
    @gateway.store(@credit_card, options)
  end

  def test_sucessful_update
    @gateway.expects(:ssl_post).returns(successful_update_response)

    assert response = @gateway.store(@credit_card, @options)
    assert_instance_of EwayManagedGateway::EwayResponse, response
    assert_equal "OK", response.message
    assert_success response
    assert response.test?
  end

  def test_successful_retrieve
    @gateway.expects(:ssl_post).returns(successful_retrieve_response)

    assert response = @gateway.retrieve(@valid_customer_id)
    assert_instance_of EwayManagedGateway::EwayResponse, response
    assert_equal "OK", response.message
    assert_success response
    assert response.test?
  end

  def test_expected_retrieve_response
    @gateway.expects(:ssl_post).with { |endpoint, data, headers|
      # Compare the actual and expected XML documents, by converting them to Hashes first
      expected = Hash.from_xml(expected_retrieve_request)
      actual = Hash.from_xml(data)
      expected == actual
    }.returns(successful_retrieve_response)
    @gateway.retrieve(@valid_customer_id)
  end

  def test_default_currency
    assert_equal 'AUD', EwayManagedGateway.default_currency
  end

  private

  def successful_purchase_response
    <<-XML
<?xml version="1.0" encoding="utf-8"?>
<soap12:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap12="http://www.w3.org/2003/05/soap-envelope">
  <soap12:Body>
    <ProcessPaymentResponse xmlns="https://www.eway.com.au/gateway/managedpayment">
      <ewayResponse>
        <ewayTrxnError>00,Transaction Approved(Test Gateway)</ewayTrxnError>
        <ewayTrxnStatus>True</ewayTrxnStatus>
        <ewayTrxnNumber>123456</ewayTrxnNumber>
        <ewayReturnAmount>100</ewayReturnAmount>
        <ewayAuthCode>123456</ewayAuthCode>
      </ewayResponse>
    </ProcessPaymentResponse>
  </soap12:Body>
</soap12:Envelope>
    XML
  end

  def unsuccessful_authorization_response
    <<-XML
<?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><soap:Body><soap:Fault><soap:Code><soap:Value>soap:Sender</soap:Value></soap:Code><soap:Reason><soap:Text xml:lang="en">Login failed</soap:Text></soap:Reason><soap:Detail /></soap:Fault></soap:Body></soap:Envelope>
    XML
  end

  def successful_store_response
    <<-XML
<?xml version="1.0" encoding="utf-8"?>
<soap12:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap12="http://www.w3.org/2003/05/soap-envelope">
  <soap12:Body>
    <CreateCustomerResponse xmlns="https://www.eway.com.au/gateway/managedpayment">
      <CreateCustomerResult>1234567</CreateCustomerResult>
    </CreateCustomerResponse>
  </soap12:Body>
</soap12:Envelope>
    XML
  end

  def successful_update_response
    <<-XML
<?xml version="1.0" encoding="utf-8"?>
<soap12:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap12="http://www.w3.org/2003/05/soap-envelope">
  <soap12:Body>
    <UpdateCustomerResponse xmlns="https://www.eway.com.au/gateway/managedpayment">
      <UpdateCustomerResult>true</UpdateCustomerResult>
    </UpdateCustomerResponse>
  </soap12:Body>
</soap12:Envelope>
    XML
  end

  # Documented here: https://www.eway.com.au/gateway/ManagedPaymentService/managedCreditCardPayment.asmx?op=QueryCustomer
  def successful_retrieve_response
    <<-XML
    <?xml version="1.0" encoding="utf-8"?>
    <soap12:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap12="http://www.w3.org/2003/05/soap-envelope">
      <soap12:Body>
        <QueryCustomerResponse xmlns="https://www.eway.com.au/gateway/managedpayment">
        <QueryCustomerResult>
          <CCName>#{@credit_card.first_name} #{@credit_card.last_name}</CCName>
          <CCNumber>#{@credit_card.number}</CCNumber>
          <CCExpiryMonth>#{sprintf("%.2i", @credit_card.month)}</CCExpiryMonth>
          <CCExpiryYear>#{sprintf("%.4i", @credit_card.year)[-2..-1]}</CCExpiryYear>
        </QueryCustomerResult>
        </QueryCustomerResponse>
      </soap12:Body>
    </soap12:Envelope>
    XML
  end

  # Documented here: https://www.eway.com.au/gateway/ManagedPaymentService/managedCreditCardPayment.asmx?op=CreateCustomer
  def expected_store_request
    <<-XML
<?xml version="1.0" encoding="utf-8"?>
<soap12:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap12="http://www.w3.org/2003/05/soap-envelope">
  <soap12:Header>
    <eWAYHeader xmlns="https://www.eway.com.au/gateway/managedpayment">
      <eWAYCustomerID>login</eWAYCustomerID>
      <Username>username</Username>
      <Password>password</Password>
    </eWAYHeader>
  </soap12:Header>
  <soap12:Body>
    <CreateCustomer xmlns="https://www.eway.com.au/gateway/managedpayment">
      <Title>Mr.</Title>
      <FirstName>#{@credit_card.first_name}</FirstName>
      <LastName>#{@credit_card.last_name}</LastName>
      <Address>#{@options[:billing_address][:address1]}</Address>
      <Suburb>#{@options[:billing_address][:city]}</Suburb>
      <State>#{@options[:billing_address][:state]}</State>
      <Company>#{@options[:billing_address][:company]}</Company>
      <PostCode>#{@options[:billing_address][:zip]}</PostCode>
      <Country>#{@options[:billing_address][:country]}</Country>
      <Email>#{@options[:email]}</Email>
      <Fax></Fax>
      <Phone>#{@options[:billing_address][:phone]}</Phone>
      <Mobile></Mobile>
      <CustomerRef>#{@options[:customer]}</CustomerRef>
      <JobDesc></JobDesc>
      <Comments>#{@options[:description]}</Comments>
      <URL></URL>
      <CCNumber>#{@credit_card.number}</CCNumber>
      <CCNameOnCard>#{@credit_card.first_name} #{@credit_card.last_name}</CCNameOnCard>
      <CCExpiryMonth>#{sprintf("%.2i", @credit_card.month)}</CCExpiryMonth>
      <CCExpiryYear>#{sprintf("%.4i", @credit_card.year)[-2..-1]}</CCExpiryYear>
    </CreateCustomer>
  </soap12:Body>
</soap12:Envelope>
    XML
  end

    # Documented here: https://www.eway.com.au/gateway/ManagedPaymentService/managedCreditCardPayment.asmx?op=CreateCustomer
    def expected_purchase_request
      <<-XML
<?xml version="1.0" encoding="utf-8"?>
<soap12:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap12="http://www.w3.org/2003/05/soap-envelope">
  <soap12:Header>
    <eWAYHeader xmlns="https://www.eway.com.au/gateway/managedpayment">
      <eWAYCustomerID>login</eWAYCustomerID>
      <Username>username</Username>
      <Password>password</Password>
    </eWAYHeader>
  </soap12:Header>
  <soap12:Body>
    <ProcessPayment xmlns="https://www.eway.com.au/gateway/managedpayment">
      <managedCustomerID>#{@valid_customer_id}</managedCustomerID>
      <amount>#{@amount}</amount>
      <invoiceReference>#{@options[:order_id] || @options[:invoice]}</invoiceReference>
      <invoiceDescription>#{@options[:description]}</invoiceDescription>
    </ProcessPayment>
  </soap12:Body>
</soap12:Envelope>
      XML
    end

    # Documented here: https://www.eway.com.au/gateway/ManagedPaymentService/managedCreditCardPayment.asmx?op=QueryCustomer
  def expected_retrieve_request
    <<-XML
  <?xml version="1.0" encoding="utf-8"?>
  <soap12:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap12="http://www.w3.org/2003/05/soap-envelope">
    <soap12:Header>
      <eWAYHeader xmlns="https://www.eway.com.au/gateway/managedpayment">
        <eWAYCustomerID>login</eWAYCustomerID>
        <Username>username</Username>
        <Password>password</Password>
      </eWAYHeader>
    </soap12:Header>
    <soap12:Body>
      <QueryCustomer xmlns="https://www.eway.com.au/gateway/managedpayment">
        <managedCustomerID>#{@valid_customer_id}</managedCustomerID>
      </QueryCustomer>
    </soap12:Body>
  </soap12:Envelope>
    XML
  end

end
