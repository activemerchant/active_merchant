#!/usr/bin/env ruby
$:.unshift(File.dirname(__FILE__) + '/../lib')
$:.unshift(File.dirname(__FILE__) + '/mocks')
$:.unshift(File.dirname(__FILE__) + '/extra')

require 'rubygems'
require 'money'
require 'yaml'
require 'net/http'
require 'net/https'
require 'test/unit'
require 'binding_of_caller'
require 'breakpoint'
require 'openssl'
require 'mocha'
require 'digest/md5'

require File.dirname(__FILE__) + '/../lib/active_merchant'

ActiveMerchant::Billing::Base.mode = :test

module Test
  module Unit
    class TestCase
      include ActiveMerchant::Billing
    end

    module Assertions
      def assert_field(field, value)
        clean_backtrace do 
          assert_equal value, @helper.fields[field]
        end
      end

      private
      def generate_order_id
        md5 = Digest::MD5.new
        now = Time.now
        md5 << now.to_s
        md5 << String(now.usec)
        md5 << String(rand(0))
        md5 << String($$)
        md5 << self.class.name
        md5.hexdigest
      end
      
      def clean_backtrace(&block)
        yield
      rescue AssertionFailedError => e
        path = File.expand_path(__FILE__)
        raise AssertionFailedError, e.message, e.backtrace.reject { |line| File.expand_path(line) =~ /#{path}/ }
      end
      
      def credit_card(number, options = {})
        defaults = {
          :number => number,
          :month => 9,
          :year => Time.now.year + 1,
          :first_name => 'Longbob',
          :last_name => 'Longsen',
          :verification_value => '123'
        }.update(options)

        ActiveMerchant::Billing::CreditCard.new(defaults)
      end
    end
  end
end
