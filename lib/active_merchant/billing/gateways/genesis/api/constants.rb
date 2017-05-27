%w(transaction errors).each do |file|
  require_relative "constants/#{file}"
end
