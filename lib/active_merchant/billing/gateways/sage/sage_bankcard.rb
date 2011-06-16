require File.dirname(__FILE__) + '/sage_core'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class SageBankcardGateway < Gateway #:nodoc:
      include SageCore
      self.url = 'https://www.sagepayments.net/cgi-bin/eftBankcard.dll?transaction'
      self.source = 'bankcard'
          
      # Credit cards supported by Sage
      # * VISA
      # * MasterCard
      # * AMEX
      # * Diners
      # * Carte Blanche
      # * Discover
      # * JCB
      # * Sears
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :jcb, :diners_club]
      
      def authorize(money, credit_card, options = {})
        post = {}
        add_credit_card(post, credit_card)
        add_transaction_data(post, money, options)
        commit(:authorization, post)
      end
      
      def purchase(money, credit_card, options = {})
        post = {}
        add_credit_card(post, credit_card)
        add_transaction_data(post, money, options)
        commit(:purchase, post)
      end                       
    
      # The +money+ amount is not used. The entire amount of the 
      # initial authorization will be captured.
      def capture(money, reference, options = {})
        post = {}
        add_reference(post, reference)
        commit(:capture, post)
      end
      
      def void(reference, options = {})
        post = {}
        add_reference(post, reference)
        commit(:void, post)
      end
      
      def credit(money, credit_card, options = {})
        post = {}
        add_credit_card(post, credit_card)
        add_transaction_data(post, money, options)
        commit(:credit, post)
      end
      
      def recurring(money, credit_card, options = {})
        post = {}
        add_credit_card(post, credit_card)
        add_amount(post, money)
        add_addresses(post, options)
        add_recurring(post, money, options)
        commit(:purchase, post)
      end
          
      private
      def exp_date(credit_card)
        year  = sprintf("%.4i", credit_card.year)
        month = sprintf("%.2i", credit_card.month)

        "#{month}#{year[-2..-1]}"
      end
      
      def add_recurring(post, money, options)
        post[:T_recurring] = 1
        post[:T_recurring_amount] = amount(money)
        post[:T_recurring_type] = (options[:type].try(:to_sym) == :daily ? 2 : 1)
        post[:T_recurring_interval] = options[:interval] || 1
        post[:T_recurring_non_business_days] =  case options[:non_business_days]
                                                when :before
                                                  1
                                                when :after
                                                  0
                                                else 
                                                  0
                                                end
        post[:T_recurring_start_date] = (options[:start_date] || Date.today).strftime('%D')
        post[:T_recurring_indefinite] = (options[:indefinite] ? '1' : '0')
        post[:T_recurring_times_to_process] = options[:times_to_process]
        post[:T_recurring_group] = options[:group]
        post[:T_recurring_payment] = options[:payment]
      end

      def add_credit_card(post, credit_card)
        post[:C_name]       = credit_card.name
        post[:C_cardnumber] = credit_card.number
        post[:C_exp]        = exp_date(credit_card)
        post[:C_cvv]        = credit_card.verification_value if credit_card.verification_value?
      end
      
      def parse(data)
        response = {}
        response[:success]          = data[1,1]
        response[:code]             = data[2,6]
        response[:message]          = data[8,32].strip
        response[:front_end]        = data[40, 2]
        response[:cvv_result]       = data[42, 1]
        response[:avs_result]       = data[43, 1].strip
        response[:risk]             = data[44, 2]
        response[:reference]        = data[46, 10]
        
        response[:order_number], response[:recurring] = data[57...-1].split("\034")
        response
      end
    end
  end
end

