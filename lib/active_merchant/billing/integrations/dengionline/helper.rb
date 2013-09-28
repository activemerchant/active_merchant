require 'active_merchant/billing/integrations/dengionline/background_response'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Dengionline
        class Helper < ActiveMerchant::Billing::Integrations::Helper
          include Common
          
          MOBILE_PAYMENT_VALUE = "mobilePayment"
          
          def initialize(order, account, options = {})
            super(order, account)
            
            self.service_url = options.delete(:service_url)
            self.secret      = options.delete(:secret)
            self.pay_method  = options.delete(:method)
            self.background  = options.delete(:mode)
            
            options.each do |key, value|
              add_field mappings[key], value
            end
            
            if background?
              if qiwi?
                add_field mappings[:transaction_type], MOBILE_PAYMENT_VALUE
                add_field mappings[:qiwi], 1
                add_field mappings[:md5], generate_qiwi_signature
              elsif mobile?
                add_field mappings[:transaction_type], MOBILE_PAYMENT_VALUE
                add_field mappings[:mobile], 1
                add_field mappings[:md5], generate_mobile_signature
              elsif remittance?
                add_field mappings[:xml], 1
                add_field mappings[:md5], generate_remittance_signature
              elsif credit_card? or alfaclick?
                add_field mappings[:xml], 1
              end
            end
          end
          
          def params
            @fields
          end
          
          def valid?
            validate if @errors.nil?
            @errors.empty?
          end
          
          def errors
            validate if @errors.nil?
            @errors
          end
          
          def background_request
            if background? and valid?
              BackgroundResponse.new params, {:service_url => service_url, :method => pay_method}
            end
          end
          
          # required
          mapping :account,           'project'
          mapping :transaction_type,  'mode_type'
          mapping :amount,            'amount'
          mapping :nickname,          'nickname'
          
          # additional
          mapping :source,            'source'
          mapping :order,             'order_id'
          mapping :description,       'comment'
          mapping :nick_extra,        'nick_extra'
          mapping :currency,          'paymentCurrency'
          
          # need for methods
          mapping :easypay_user_id,   'easypay_card'          # easypay
          mapping :mailru_user_id,    'mailru_buyer_email'    # mailru
          mapping :alfa_user_id,      'AlfaClickUserID'       # alfa click
          mapping :mobile_user_id,    'qiwi_phone'            # qiwi, mobile
          
          mapping :qiwi,              'sendQIWIPayment'       # qiwi
          mapping :mobile,            'sendMobilePayment'     # mobile
          mapping :xml,               'xml'                   # remittance, credit card, alfa click
          mapping :md5,               'md5'                   # qiwi, mobile, remittance
          
          private
          
          def validate
            @errors = []
            
            @errors << 'project'    unless params['project'].to_s =~ /^\d+$/
            @errors << 'mode_type'  if params['mode_type'].to_s.empty?
            @errors << 'amount'     unless params['amount'].to_s =~ /^\d+\.?\d*$/
            @errors << 'nickname'   if params['nickname'].to_s.empty?
            
            if easypay?
              @errors << 'mode_type'          if params['mode_type'].to_i != 16
              @errors << 'easypay_card'       if params['easypay_card'].to_s.empty?
            elsif mailru?
              @errors << 'mode_type'          if params['mode_type'].to_i != 32
              @errors << 'mailru_buyer_email' if params['mailru_buyer_email'].to_s.empty?
            elsif qiwi?
              @errors << 'mode_type'          if not background? and params['mode_type'].to_i != 14
              @errors << 'qiwi_phone'         unless params['qiwi_phone'].to_s =~ /^\d{10}$/
            elsif mobile?
              @errors << 'qiwi_phone'         unless params['qiwi_phone'].to_s =~ /^\d{10}$/
            elsif remittance?
              m = params['mode_type'].to_i
              @errors << 'mode_type'          unless [54, 62, 75].include? m
              @errors << 'order_id'           if params['order_id'].to_s.empty?
              @errors << 'source'             if params['source'].to_s.empty?
            elsif credit_card?
              if background?
                m = params['mode_type'].to_i
                #@errors << 'mode_type'          unless [108, 109, 110, 263, 342].include? m
                @errors << 'order_id'           if params['order_id'].to_s.empty?
              end
            elsif alfaclick?
              m = params['mode_type'].to_i
              @errors << 'mode_type'          if params['mode_type'].to_i != 76
              @errors << 'AlfaClickUserID'    if params['AlfaClickUserID'].to_s.empty?
            end
          end
          
        end
      end
    end
  end
end
