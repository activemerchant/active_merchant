#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    class PKIRequestStringBuilder
      attr_accessor :request_string

      def initialize(request_string = '')
        @request_string = request_string
      end

      def append_super(super_request_string)
        unless super_request_string.nil?

          s = super_request_string[1..-2]
          if s.length > 0
            retval = @request_string + s
            retval << ','
          end
          @request_string = retval
        end
        self
      end

      def append(key, value = nil)
        unless value.nil?
          if value.is_a? PKIRequestStringConvertible
            append_key_value(key, value.to_PKI_request_string)
          else
            append_key_value(key, value)
          end
        end
        self
      end


      def append_array(key, array = nil)
        unless array.nil?
          appended_value = ''
          array.each do |value|
            if value.is_a? PKIRequestStringConvertible
              appended_value << value.to_PKI_request_string
            else
              appended_value << value
            end
            appended_value << ', '
          end
          append_key_value_array(key, appended_value)
        end
        self
      end

      def append_key_value(key, value)
        @request_string = "#{@request_string}#{key}=#{value}," unless value.nil?
      end

      def append_key_value_array(key, value)
        unless value.nil?
          sub = ', '
          value = value.gsub(/[#{sub}]+$/, '')
          @request_string = "#{@request_string}#{key}=[#{value}],"
        end

        self
      end

      def append_prefix
        @request_string = "[#{@request_string}]"
      end

      def remove_trailing_comma
        sub = ','
        @request_string = @request_string.gsub(/[#{sub}]+$/, '')
      end

      def get_request_string
        remove_trailing_comma
        append_prefix

        @request_string
      end
    end
  end
end
