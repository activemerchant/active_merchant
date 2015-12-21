#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module CardStorage
      module Response
      end
    end
  end
end

require_relative 'Response/Mapper'
require_relative 'Response/CreateCardResponse'
require_relative 'Response/DeleteCardResponse'
require_relative 'Response/RetrieveCardListResponse'