# ARB
module AuthorizeNetArb #:nodoc:
  def get_recurring_transaction
    gateway = test? ? :sandbox : :live
    test_mode = test? ? partial_test_mode : true
    transaction = AuthorizeNet::ARB::Transaction.new(@options[:login], @options[:password], :gateway => gateway, :test => test_mode)
  end

  def create_recurring_data(options)
    requires!(options, :interval, :duration, :billing_address)
    requires!(options[:interval], :length, [:unit, :days, :months])
    requires!(options[:duration], :start_date, :occurrences)
    requires!(options[:billing_address], :first_name, :last_name)

    subscription = AuthorizeNet::ARB::Subscription.new(
        :name => options[:subscription_name],
        :length => options[:interval][:length],
        :unit => options[:interval][:unit],
        :start_date => options[:duration][:start_date],
        :total_occurrences => options[:duration][:occurrences],
        :trial_occurrences => nil,
        :amount => options[:amount],
        :trial_amount => nil,
        :invoice_number => options[:invoice_number],
        :description => options[:description],
        :subscription_id => nil,
        :credit_card => get_payment_source(options[:credit_card], options),
        :billing_address => AuthorizeNet::Address.new(options[:billing_address])
    )
  end

  def update_recurring_data(options)
    mapped_options = Hash(options)

    if options[:subscription_name]
      mapped_options[:name] = options[:subscription_name]
    end

    if options[:interval] && options[:interval][:length]
      mapped_options[:length] = options[:interval][:length]
    end

    if options[:interval] && options[:interval][:unit]
      mapped_options[:unit] = options[:interval][:unit]
    end

    if options[:duration] && options[:duration][:start_date]
      mapped_options[:start_date] = options[:duration][:start_date]
    end

    if options[:duration] && options[:duration][:occurrences]
      mapped_options[:total_occurrences] = options[:duration][:occurrences]
    end

    if options[:billing_address]
      mapped_options[:billing_address] = AuthorizeNet::Address.new(options[:billing_address])
    end

    if options[:credit_card]
      mapped_options[:credit_card] = add_credit_card(options[:credit_card])
    end
    subscription = AuthorizeNet::ARB::Subscription.new(mapped_options)
  end

  def build_active_merchant_subscription_response(anet_subscription_response)
    hashed_response = get_hash(anet_subscription_response)
    hashed_response['code'] = hashed_response['message_code']
    ActiveMerchant::Billing::Response.new(anet_subscription_response.success?, anet_subscription_response.message_text, hashed_response,
                                          :test => test?,
                                          :authorization => anet_subscription_response.subscription_id
    )
  end
end