#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Basic
      module Installment
        module Response
          module Mapper

            class InstallmentInfoResponseMapper < ResponseMapper

              def map_response(response, jsonResult)
                super
                response.installment_details = map_installment_details(jsonResult['installmentDetails']) unless jsonResult['installmentDetails'].nil?
              end

              def map_installment_details(installment_details)
                installment_detail_dtos = Array.new
                installment_details.each do |installment_detail|
                  installment_detail_dto = Dto::InstallmentDetailDto::new
                  installment_detail_dto.binNumber = installment_detail['binNumber'] unless installment_detail['binNumber'].nil?
                  installment_detail_dto.price = installment_detail['price'] unless installment_detail['price'].nil?
                  installment_detail_dto.cardType = installment_detail['cardType'] unless installment_detail['cardType'].nil?
                  installment_detail_dto.cardAssociation = installment_detail['cardAssociation'] unless installment_detail['cardAssociation'].nil?
                  installment_detail_dto.cardFamilyName = installment_detail['cardFamilyName'] unless installment_detail['cardFamilyName'].nil?
                  installment_detail_dto.force3ds = installment_detail['force3ds'] unless installment_detail['force3ds'].nil?
                  installment_detail_dto.bankCode = installment_detail['bankCode'] unless installment_detail['bankCode'].nil?
                  installment_detail_dto.bankName = installment_detail['bankName'] unless installment_detail['bankName'].nil?
                  installment_detail_dto.installmentPrices = map_installment_prices(installment_detail['installmentPrices']) unless installment_detail['installmentPrices'].nil?
                  installment_detail_dtos << installment_detail_dto
                end
                installment_detail_dtos
              end

              def map_installment_prices(installment_prices)
                installment_prices_dtos = Array.new
                installment_prices.each do |installment_price|
                  installment_price_dto = Dto::InstallmentPriceDto::new
                  installment_price_dto.installmentPrice = installment_price['installmentPrice'] unless installment_price['installmentPrice'].nil?
                  installment_price_dto.totalPrice = installment_price['totalPrice'] unless installment_price['totalPrice'].nil?
                  installment_price_dto.installmentNumber = installment_price['installmentNumber'] unless installment_price['installmentNumber'].nil?
                  installment_prices_dtos << installment_price_dto
                end
                installment_prices_dtos
              end

            end
          end
        end
      end
    end
  end
end
