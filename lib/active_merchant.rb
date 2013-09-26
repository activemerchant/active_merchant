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
require 'active_support/core_ext/class/attribute_accessors'
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

require 'active_utils'
require 'active_merchant/billing'
require 'active_merchant/version'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    autoload :Integrations, 'active_merchant/billing/integrations'
  end
end
