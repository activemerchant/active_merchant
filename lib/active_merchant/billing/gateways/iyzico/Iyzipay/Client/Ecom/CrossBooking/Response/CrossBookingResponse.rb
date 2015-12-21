#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Ecom
      module CrossBooking
        module Response
          class CrossBookingResponse < Iyzipay::Client::Response

            def from_json(json_result)
              Mapper::CrossBookingResponseMapper.new.map_response(self, json_result)
            end

          end
        end
      end
    end
  end
end
