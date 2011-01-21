


class_dir  = 'lib/active_merchant/billing/gateways'
remote_dir = "test/remote/gateways"
unit_dir   = 'test/unit/gateways'

watch("#{class_dir}/(.*)\.rb") do |file|
	to_run  = ["#{unit_dir}/#{file[1]}_test.rb", "#{remote_dir}/remote_#{file[1]}_test.rb"]
	puts "running \"#{to_run.join(' ')}\""
	to_run.each{ |x| system "ruby -Itest #{x}"}
end


watch("#{remote_dir}/(.*)") do |file|
#	tom = file[1].gsub('remote_', '')
	to_run  = [ "#{remote_dir}/#{file[1]}"]
	puts "running \"#{to_run.join(' ')}\""
	to_run.each{ |x| system "ruby -Itest #{x}"}
end

watch("#{unit_dir}/(.*)") do |file|
	to_run = ["#{unit_dir}/#{file[1]}"]
	puts "running \"#{to_run.join(' ')}\""
	to_run.each{ |x| system "ruby -Itest #{x}"}
end







