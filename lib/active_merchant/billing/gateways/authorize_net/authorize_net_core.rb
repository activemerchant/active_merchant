# ARB
module AuthorizeNetCore #:nodoc:

  TRACKS = {
      1 => /^%(?<format_code>.)(?<pan>[\d]{1,19}+)\^(?<name>.{2,26})\^(?<expiration>[\d]{0,4}|\^)(?<service_code>[\d]{0,3}|\^)(?<discretionary_data>.*)\?\Z/,
      2 => /\A;(?<pan>[\d]{1,19}+)=(?<expiration>[\d]{0,4}|=)(?<service_code>[\d]{0,3}|=)(?<discretionary_data>.*)\?\Z/
  }.freeze

  private

  def get_transaction
    gateway = test? ? :sandbox : :live
    test_mode = test? ? partial_test_mode : true
    transaction = AuthorizeNet::AIM::Transaction.new(@options[:login], @options[:password], :gateway => gateway, :test => test_mode)
  end

  def build_active_merchant_response(anet_response)
    ActiveMerchant::Billing::Response.new(anet_response.success?, anet_response.fields[:response_reason_text], anet_response.fields,
                                          :test => test?,
                                          :authorization => anet_response.authorization_code
    #:avs_result => response.avs_response
    #{:cvv_result => response.card_code}
    )
  end

  def get_hash(instance)
    hash = {}
    instance.instance_variables.each { |var| hash[var.to_s.delete("@")] = instance.instance_variable_get(var) }
    hash
  end

  def success?(response)
    response[:response_code] == APPROVED && TRANSACTION_ALREADY_ACTIONED.exclude?(response[:response_reason_code])
  end

  def fraud_review?(response)
    response[:response_code] == FRAUD_REVIEW
  end

  def get_action_type(action)
    type = ACTION_TYPES[action]
  end

  def add_currency_code(transaction, money, options)
    # post[:currency_code] = options[:currency] || currency(money)
  end

  def add_invoice(transaction, options)
    transaction.fields[:invoice_num] = options[:order_id]
    transaction.fields[:description] = options[:description]
  end

  def get_payment_source(source, options={})
    if card_brand(source) == "check"
      add_check(source, options)
    else
      anet_credit_card = add_creditcard(source, options)
      add_swipe_data(source, anet_credit_card)
    end
  end

  def add_creditcard(creditcard, options={})
    options[:card_type] = creditcard.brand
    options[:card_code] = creditcard.verification_value if creditcard.verification_value?
    #options[:first_name] = creditcard.first_name
    #options[:last_name] = creditcard.last_name
    @payment_source = AuthorizeNet::CreditCard.new(creditcard.number, expdate(creditcard), options)
  end

  def add_swipe_data(active_merchant_credit_card, anet_credit_card)
    if (TRACKS[1].match(active_merchant_credit_card.track_data))
      anet_credit_card.track_1 = active_merchant_credit_card.track_data
    elsif (TRACKS[2].match(active_merchant_credit_card.track_data))
      anet_credit_card.track_2 = active_merchant_credit_card.track_data
    end
    anet_credit_card
  end

  def add_check(check, options={})
    options[:echeck_type] = "WEB"
    options[:check_number] = check.number if check.number.present?
    options[:recurring] = (options[:recurring] ? "TRUE" : "FALSE")
    @payment_source = AuthorizeNet::ECheck.new(check.routing_number, check.account_number, check.bank_name, check.name, options)
  end

  def add_customer_data(transaction, options)
    if options.has_key? :email
      transaction.fields[:email] = options[:email]
      transaction.fields[:email_customer] = false
    end

    if options.has_key? :customer
      transaction.fields[:cust_id] = options[:customer] if Float(options[:customer]) rescue nil
    end

    if options.has_key? :ip
      transaction.fields[:customer_ip] = options[:ip]
    end

    if options.has_key? :cardholder_authentication_value
      transaction.fields[:cardholder_authentication_value] = options[:cardholder_authentication_value]
    end

    if options.has_key? :authentication_indicator
      transaction.fields[:authentication_indicator] = options[:authentication_indicator]
    end

  end

  # x_duplicate_window won't be sent by default, because sending it changes the response.
  # "If this field is present in the request with or without a value, an enhanced duplicate transaction response will be sent."
  # (as of 2008-12-30) http://www.authorize.net/support/AIM_guide_SCC.pdf
  def add_duplicate_window(transaction)
    unless duplicate_window.nil?
      transaction.fields[:duplicate_window] = duplicate_window
    end
  end

  def add_address(transaction, options)
    if address_hash = options[:billing_address] || options[:address]
      address_to_add = AuthorizeNet::Address.new

      address_to_add.street_address = address_hash[:address1].to_s
      address_to_add.company = address_hash[:company].to_s
      address_to_add.phone = address_hash[:phone].to_s
      address_to_add.zip = address_hash[:zip].to_s
      address_to_add.city = address_hash[:city].to_s
      address_to_add.country = address_hash[:country].to_s
      address_to_add.state = address_hash[:state].blank? ? 'n/a' : address_hash[:state]

      transaction.set_address(address_to_add)
    end

    if address_hash = options[:shipping_address]
      address_to_add = AuthorizeNet::ShippingAddress.new

      address_to_add.first_name = address_hash[:first_name].to_s
      address_to_add.last_name = address_hash[:last_name].to_s

      address_to_add.street_address = address_hash[:address1].to_s
      address_to_add.company = address_hash[:company].to_s
      address_to_add.phone = address_hash[:phone].to_s
      address_to_add.zip = address_hash[:zip].to_s
      address_to_add.city = address_hash[:city].to_s
      address_to_add.country = address_hash[:country].to_s
      address_to_add.state = address_hash[:state].blank? ? 'n/a' : address_hash[:state]

      transaction.set_shipping_address(address_to_add)
    end

  end

  # Make a ruby type out of the response string
  def normalize(field)
    case field
      when "true" then
        true
      when "false" then
        false
      when "" then
        nil
      when "null" then
        nil
      else
        field
    end
  end

  def expdate(creditcard)
    unless creditcard.year == nil
      year = sprintf("%.4i", creditcard.year)
      month = sprintf("%.2i", creditcard.month)

      "#{month}#{year[-2..-1]}"
    end
  end

  def split(response)
    response[1..-2].split(/\$,\$/)
  end
end