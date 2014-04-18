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
    #todo finish the mapping
    mapped_options = Hash[options.map { |key, value| [key, value] }]

    subscription = AuthorizeNet::ARB::Subscription.new(mapped_options)
  end

  def build_active_merchant_subscription_response(anet_subscription_response)
    ActiveMerchant::Billing::Response.new(anet_subscription_response.success?, anet_subscription_response.message_text, get_hash(anet_subscription_response),
                                          :test => test?,
                                          :authorization => anet_subscription_response.subscription_id
    )
  end
end