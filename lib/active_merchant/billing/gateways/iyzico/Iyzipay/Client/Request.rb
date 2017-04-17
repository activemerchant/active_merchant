#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    class Request < RequestDto
      attr_accessor :locale, :conversationId

      def initialize
        @locale = nil
        @conversationId = nil
      end

      def get_json_object
        JsonBuilder.new_instance.
            add('locale', @locale).
            add('conversationId', @conversationId).
            get_object
      end

      def to_PKI_request_string
        PKIRequestStringBuilder.new.append(:locale, @locale).
            append(:conversationId, @conversationId).
            get_request_string
      end
    end
  end
end
