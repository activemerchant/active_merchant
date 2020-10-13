require 'rubygems'

begin
  require "bundler/gem_tasks"
rescue LoadError
end

require 'rdoc/task'
require 'rake/testtask'

task :prerelease => [:clobber_rdoc, :test]

desc "Update SSL Certificate"
task('ssl_cert') do |p|
  sh "openssl genrsa -des3 -out server.key 1024"
  sh "openssl req -new -key server.key -out server.csr"
  sh "cp server.key server.key.org"
  sh "openssl rsa -in server.key.org -out server.key"
  sh "openssl x509 -req -days 365 -in server.csr -signkey server.key -out server.crt"
  sh "cp server.key server.pem"
  sh "mv server.key server.csr server.crt server.pem test/data/"
  sh "rm server.key.org"
end

RDoc::Task.new do |rdoc|
  rdoc.main = "README.rdoc"
  rdoc.rdoc_dir = 'doc'
  rdoc.rdoc_files.include( "CHANGELOG.rdoc", "EXAMPLES.rdoc", "GUIDE.rdoc", "LICENSE.rdoc", "README.rdoc", "lib/**/*.rb")
end

desc "Run tests"
Rake::TestTask.new { |t|
  t.test_files = Dir['test/**/test*.rb']
  t.verbose = true
}

task publish_docs: %w[rdoc] do
  sh 'rsync', '-avzO', '--delete', 'doc/', 'docs-push.seattlerb.org:/data/www/docs.seattlerb.org/mechanize/'
end

task default: :test
