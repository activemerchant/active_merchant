#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    class JsonBuilder
      attr_accessor :json

      def initialize(json)
        @json = json
      end

      def self.new_instance
        JsonBuilder.new(Hash.new)
      end

      def self.from_json_object(json)
        JsonBuilder.new(json)
      end

      def add(key, value = nil)
        unless value.nil?
          if value.is_a? JsonConvertible
            @json[key] = value.get_json_object
          else
            @json[key] = value
          end
        end
        self
      end

      def add_array(key, array = nil)
        unless array.nil?
          json_array = Array.new
          array.each_with_index do |value,index|
            if value.is_a? JsonConvertible
              json_array[index] = value.get_json_object
            else
              json_array[index] = value
            end
            json[key] = json_array
          end
        end
        self
      end

      def get_object
        json
      end
    end
  end
end
