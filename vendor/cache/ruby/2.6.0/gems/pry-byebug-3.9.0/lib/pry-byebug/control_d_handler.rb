# frozen_string_literal: true

original_handler = Pry.config.control_d_handler

Pry.config.control_d_handler = proc do |pry_instance|
  Byebug.stop if Byebug.stoppable?

  original_handler.call(pry_instance)
end
