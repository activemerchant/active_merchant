#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    class RequestDto < PKIRequestStringConvertible
      def to_json_string
        get_json_object.to_json
      end
    end
  end
end
