#--
# Copyright (c) 2005-2010 Tobias Luetke
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#++

require 'active_support'
require 'active_support/core_ext/string/inflections'
require 'active_support/core_ext/hash/indifferent_access'
require 'active_support/core_ext/hash/conversions'
require 'active_support/core_ext/object/conversions'
require 'active_support/core_ext/class/attribute'
require 'active_support/core_ext/enumerable.rb'

if(!defined?(ActiveSupport::VERSION) || (ActiveSupport::VERSION::STRING < "4.1"))
  require 'active_support/core_ext/class/attribute_accessors'
end

require 'active_support/core_ext/class/delegating_attributes'
require 'active_support/core_ext/module/attribute_accessors'

begin
  require 'active_support/base64'

  unless defined?(Base64)
    Base64 = ActiveSupport::Base64
  end

  unless Base64.respond_to?(:strict_encode64)
    def Base64.strict_encode64(v)
      ActiveSupport::Base64.encode64s(v)
    end
  end
rescue LoadError
  require 'base64'
end

require 'securerandom'
require 'builder'
require 'cgi'
require 'rexml/document'
require 'timeout'
require 'socket'

require 'active_utils/common/network_connection_retries'
silence_warnings{require 'active_utils/common/connection'}
require 'active_utils/common/post_data'
require 'active_utils/common/posts_data'

require 'active_merchant/billing'
require 'active_merchant/version'
require 'active_merchant/country'

I18n.enforce_available_locales = false

module ActiveMerchant #:nodoc:
  OFFSITE_PAYMENT_EXTRACTION_MESSAGE = "Integrations have been extracted into a separate gem (https://github.com/Shopify/offsite_payments) and will no longer be loaded by ActiveMerchant 2.x."

  module Billing #:nodoc:
    def self.const_missing(name)
      if name.to_s == "Integrations"
        ActiveMerchant.deprecated(OFFSITE_PAYMENT_EXTRACTION_MESSAGE)
        require "active_merchant/offsite_payments_shim"
        ActiveMerchant::OffsitePaymentsShim
      else
        super
      end
    end

    def self.included(klass)
      def klass.const_missing(name)
        if name.to_s == "Integrations"
          ActiveMerchant.deprecated(OFFSITE_PAYMENT_EXTRACTION_MESSAGE)
          require "active_merchant/offsite_payments_shim"
          ActiveMerchant::OffsitePaymentsShim
        else
          super
        end
      end
    end
  end

  def self.deprecated(message, caller=Kernel.caller[1])
    warning = caller + ": " + message
    if(respond_to?(:logger) && logger.present?)
      logger.warn(warning)
    else
      warn(warning)
    end
  end
end
