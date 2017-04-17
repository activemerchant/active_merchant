#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    class Response
      attr_accessor :raw_result
      attr_accessor :status
      attr_accessor :error_code
      attr_accessor :error_message
      attr_accessor :error_group
      attr_accessor :locale
      attr_accessor :system_time
      attr_accessor :conversation_id

      def from_json(json_result)
        ResponseMapper.new.map_response(self, json_result)
      end
    end
  end
end
