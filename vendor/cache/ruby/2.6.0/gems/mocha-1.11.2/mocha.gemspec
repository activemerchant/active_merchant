lib = File.expand_path('../lib/', __FILE__)
$LOAD_PATH.unshift lib unless $LOAD_PATH.include?(lib)
require 'mocha/version'

Gem::Specification.new do |s| # rubocop:disable Metrics/BlockLength
  s.name = 'mocha'
  s.version = Mocha::VERSION
  s.licenses = ['MIT', 'BSD-2-Clause']
  s.required_ruby_version = '>= 1.8.7'

  s.authors = ['James Mead']
  s.description = 'Mocking and stubbing library with JMock/SchMock syntax, which allows mocking and stubbing of methods on real (non-mock) classes.'
  s.email = 'mocha-developer@googlegroups.com'

  s.files = `git ls-files`.split("\n")
  s.files.delete('.travis.yml')
  s.files.delete('.gitignore')

  s.homepage = 'https://mocha.jamesmead.org'
  s.require_paths = ['lib']
  s.summary = 'Mocking and stubbing library'

  unless s.respond_to?(:add_development_dependency)
    class << s
      def add_development_dependency(*args)
        add_dependency(*args)
      end
    end
  end

  if RUBY_VERSION >= '1.9.3'
    s.add_development_dependency('rake')
  else
    # Rake >= v11 does not support Ruby < v1.9.3 so use
    s.add_development_dependency('rake', '~> 10.0')
  end
  s.add_development_dependency('introspection', '~> 0.0.1')
  if RUBY_VERSION >= '2.2.0'
    # No test libraries in standard library
    s.add_development_dependency('minitest')
  end
  if RUBY_VERSION >= '1.9.2'
    s.add_development_dependency('rubocop', '<= 0.58.2')
  end
  if ENV['MOCHA_GENERATE_DOCS']
    s.add_development_dependency('redcarpet')
    s.add_development_dependency('yard')
  end
end
