#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module CardStorage
      module Request
      end
    end
  end
end

require_relative 'Request/CreateCardRequest'
require_relative 'Request/DeleteCardRequest'
require_relative 'Request/RetrieveCardListRequest'

