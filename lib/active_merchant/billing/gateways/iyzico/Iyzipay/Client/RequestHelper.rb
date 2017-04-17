#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    class RequestHelper
        AUTHORIZATION_HEADER_NAME = 'Authorization'
        RANDOM_HEADER_NAME = 'x-iyzi-rnd';
        AUTHORIZATION_HEADER_STRING = 'IYZWS %s:%s'
        RANDOM_STRING_SIZE = 8

        def self.format_header_string(*args)
          sprintf(RequestHelper::AUTHORIZATION_HEADER_STRING, *args)
        end
    end
  end
end
