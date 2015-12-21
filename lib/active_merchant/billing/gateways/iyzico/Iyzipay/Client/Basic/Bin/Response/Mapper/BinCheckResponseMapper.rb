#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Basic
      module Bin
        module Response
          module Mapper
            class BinCheckResponseMapper < ResponseMapper

              def map_response(response, jsonResult)
                super
                response.bin_number = jsonResult['binNumber'] unless jsonResult['binNumber'].nil?
                response.card_type = jsonResult['cardType'] unless jsonResult['cardType'].nil?
                response.card_association = jsonResult['cardAssociation'] unless jsonResult['cardAssociation'].nil?
                response.card_family = jsonResult['cardFamily'] unless jsonResult['cardFamily'].nil?
                response.bank_name = jsonResult['bankName'] unless jsonResult['bankName'].nil?
                response.bank_code = jsonResult['bankCode'] unless jsonResult['bankCode'].nil?
              end
            end
          end
        end
      end
    end
  end
end

