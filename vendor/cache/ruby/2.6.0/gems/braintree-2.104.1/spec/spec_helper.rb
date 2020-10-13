unless defined?(SPEC_HELPER_LOADED)
  SPEC_HELPER_LOADED = true
  project_root = File.expand_path(File.dirname(__FILE__) + "/..")
  require "rubygems"
  require "bundler/setup"
  require "rspec"
  require "libxml"
  require "pry"

  braintree_lib = "#{project_root}/lib"
  $LOAD_PATH << braintree_lib
  require "braintree"
  require File.dirname(__FILE__) + "/oauth_test_helper"

  Braintree::Configuration.environment = :development
  Braintree::Configuration.merchant_id = "integration_merchant_id"
  Braintree::Configuration.public_key = "integration_public_key"
  Braintree::Configuration.private_key = "integration_private_key"
  logger = Logger.new("/dev/null")
  logger.level = Logger::INFO
  Braintree::Configuration.logger = logger

  module Kernel
    alias_method :original_warn, :warn
    def warn(message)
      return if message =~ /^\[DEPRECATED\]/
      original_warn(message)
    end
  end

  def now_in_eastern
    (Time.now.utc - 5*60*60).strftime("%Y-%m-%d")
  end

  module SpecHelper

    DefaultMerchantAccountId = "sandbox_credit_card"
    NonDefaultMerchantAccountId = "sandbox_credit_card_non_default"
    NonDefaultSubMerchantAccountId = "sandbox_sub_merchant_account"
    ThreeDSecureMerchantAccountId = "three_d_secure_merchant_account"
    FakeAmexDirectMerchantAccountId = "fake_amex_direct_usd"
    FakeVenmoAccountMerchantAccountId = "fake_first_data_venmo_account"
    UsBankMerchantAccountId = "us_bank_merchant_account"
    AnotherUsBankMerchantAccountId = "another_us_bank_merchant_account"
    AdyenMerchantAccountId = "adyen_ma"
    HiperBRLMerchantAccountId = "hiper_brl"

    TrialPlan = {
      :description => "Plan for integration tests -- with trial",
      :id => "integration_trial_plan",
      :price => BigDecimal("43.21"),
      :trial_period => true,
      :trial_duration => 2,
      :trial_duration_unit => Braintree::Subscription::TrialDurationUnit::Day
    }

    TriallessPlan = {
      :description => "Plan for integration tests -- without a trial",
      :id => "integration_trialless_plan",
      :price => BigDecimal("12.34"),
      :trial_period => false
    }

    AddOnDiscountPlan = {
      :description => "Plan for integration tests -- with add-ons and discounts",
      :id => "integration_plan_with_add_ons_and_discounts",
      :price => BigDecimal("9.99"),
      :trial_period => true,
      :trial_duration => 2,
      :trial_duration_unit => Braintree::Subscription::TrialDurationUnit::Day
    }

    BillingDayOfMonthPlan = {
      :description => "Plan for integration tests -- with billing day of month",
      :id => "integration_plan_with_billing_day_of_month",
      :price => BigDecimal("8.88"),
      :billing_day_of_month => 5
    }

    AddOnIncrease10 = "increase_10"
    AddOnIncrease20 = "increase_20"
    AddOnIncrease30 = "increase_30"

    Discount7 = "discount_7"
    Discount11 = "discount_11"
    Discount15 = "discount_15"

    DefaultOrderId = "ABC123"

    TestMerchantConfig = Braintree::Configuration.new(
                                                      :logger => Logger.new("/dev/null"),
                                                      :environment => Braintree::Configuration.environment,
                                                      :merchant_id => "test_merchant_id",
                                                      :public_key => "test_public_key",
                                                      :private_key => "test_private_key"
                                                      )

    def self.make_past_due(subscription, number_of_days_past_due = 1)
      config = Braintree::Configuration.instantiate
      config.http.put(
        "#{config.base_merchant_path}/subscriptions/#{subscription.id}/make_past_due?days_past_due=#{number_of_days_past_due}"
      )
    end

    def self.settle_transaction(transaction_id)
      config = Braintree::Configuration.instantiate
      config.http.put("#{config.base_merchant_path}/transactions/#{transaction_id}/settle")
    end

    def self.create_3ds_verification(merchant_account_id, params)
      config = Braintree::Configuration.instantiate
      response = config.http.post("#{config.base_merchant_path}/three_d_secure/create_verification/#{merchant_account_id}", :three_d_secure_verification => params)
      response[:three_d_secure_verification][:three_d_secure_authentication_id]
    end

    def self.create_merchant(params={})
      gateway = Braintree::Gateway.new(
        :client_id => "client_id$#{Braintree::Configuration.environment}$integration_client_id",
        :client_secret => "client_secret$#{Braintree::Configuration.environment}$integration_client_secret",
        :logger => Logger.new("/dev/null")
      )

      gateway.merchant.create({
        :email => "name@email.com",
        :country_code_alpha3 => "GBR",
        :payment_methods => ["credit_card", "paypal"],
      }.merge!(params))
    end

    def self.stub_time_dot_now(desired_time)
      Time.class_eval do
        class << self
          alias original_now now
        end
      end
      (class << Time; self; end).class_eval do
        define_method(:now) { desired_time }
      end
      yield
    ensure
      Time.class_eval do
        class << self
          alias now original_now
        end
      end
    end

    def self.simulate_form_post_for_tr(tr_data_string, form_data_hash, url = Braintree::TransparentRedirect.url)
      response = nil
      config = Braintree::Configuration.instantiate
      http = Net::HTTP.new(config.server, config.port)
      http.use_ssl = config.ssl?
      http.start do |http|
        request = Net::HTTP::Post.new("/" + url.split("/", 4)[3])
        request.add_field "Content-Type", "application/x-www-form-urlencoded"
        request.body = Braintree::Util.hash_to_query_string({:tr_data => tr_data_string}.merge(form_data_hash))
        response = http.request(request)
      end
      if response.code.to_i == 303
        response["Location"].split("?", 2).last
      else
        raise "did not receive a valid tr response: #{response.body[0,1000].inspect}"
      end
    end

    def self.using_configuration(config = {}, &block)
      original_values = {}
      [:merchant_id, :public_key, :private_key].each do |key|
        if config[key]
          original_values[key] = Braintree::Configuration.send(key)
          Braintree::Configuration.send("#{key}=", config[key])
        end
      end
      begin
        yield
      ensure
        original_values.each do |key, value|
          Braintree::Configuration.send("#{key}=", value)
        end
      end
    end
  end

  module CustomMatchers
    class ParseTo
      def initialize(hash)
        @expected_hash = hash
      end

      def matches?(xml_string)
        @libxml_parse = Braintree::Xml::Parser.hash_from_xml(xml_string, Braintree::Xml::Libxml)
        @rexml_parse = Braintree::Xml::Parser.hash_from_xml(xml_string, Braintree::Xml::Rexml)
        if @libxml_parse != @expected_hash
          @results = @libxml_parse
          @failed_parser = "libxml"
          false
        elsif @rexml_parse != @expected_hash
          @results = @rexml_parse
          @failed_parser = "rexml"
          false
        else
          true
        end
      end

      def failure_message
        "xml parsing failed for #{@failed_parser}, expected #{@expected_hash.inspect} but was #{@results.inspect}"
      end

      def failure_message_when_negated
        raise NotImplementedError
      end
    end

    def parse_to(hash)
      ParseTo.new(hash)
    end
  end
end

RSpec.configure do |config|
  config.include CustomMatchers

  if ENV["JUNIT"] == "1"
    config.add_formatter("RspecJunitFormatter", "tmp/build/braintree-ruby.#{rand}.junit.xml")
    config.add_formatter("progress")
  end

  config.expect_with :rspec do |expect|
    expect.syntax = [:should, :expect]
  end

  config.mock_with :rspec do |mock|
    mock.syntax = [:should, :expect]
  end
end
