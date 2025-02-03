module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module PuntoPagos #:nodoc:
      class Response < Response
        def token
          @params['token']
        end

        def trx_id
          @params['trx_id']
        end

        def code
          @params['respuesta']
        end

        def auth_code
          @params['codigo_autorizacion']
        end

        def approved_at
          @params['fecha_aprobacion']
        end

        def payment_method
          @params['medio_pago']
        end

        def payment_method_description
          @params['medio_pago_descripcion']
        end

        def amount
          @params['monto']
        end

        def shares
          @params['num_cuotas']
        end

        def share_value
          @params['valor_cuota']
        end

        def share_type
          @params['tipo_cuotas']
        end

        def card_number
          @params['numero_tarjeta']
        end

        def operation_number
          @params['numero_operacion']
        end

        def first_expiration
          @params['primer_vencimiento']
        end

        def payment_type
          @params['tipo_pago']
        end
      end
    end
  end
end
