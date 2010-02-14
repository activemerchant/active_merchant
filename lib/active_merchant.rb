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
                    
$:.unshift File.dirname(__FILE__)

require 'active_support'
require 'builder'
require 'cgi'
require 'rexml/document'

require 'active_merchant/lib/utils'
require 'active_merchant/lib/error'
require 'active_merchant/lib/validateable'
require 'active_merchant/lib/connection'
require 'active_merchant/lib/posts_data'
require 'active_merchant/lib/post_data'
require 'active_merchant/lib/requires_parameters'
require 'active_merchant/lib/country'

require 'active_merchant/billing'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:    
    autoload :Integrations, 'active_merchant/billing/integrations'
  end
end
