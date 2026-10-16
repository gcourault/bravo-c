# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'bravo/version'

Gem::Specification.new do |gem|
  gem.name          = "bravo"
  gem.version       = Bravo::VERSION
  gem.authors       = ["Leandro Marcucci"]
  gem.email         = ["leanucci@gmail.com"]
  gem.description   = %q{Adaptador para el Web Service de Facturacion Electrónica de AFIP}
  gem.summary       = %q{Adaptador WSFE}
  gem.homepage      = "https://github.com/leanucci/bravo#readme"
  gem.license       = 'MIT'
  gem.required_ruby_version = '>= 3.0'

  gem.files         = `git ls-files`.split($/)
  gem.files.reject! { |f| f.include? 'vcr' }
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib", "bin"]

  gem.add_runtime_dependency(%q<savon>, ["~> 2.12"])
  gem.add_runtime_dependency(%q<thor>, [">= 0.20", "< 2"])

  gem.add_development_dependency(%q<rspec>, ["~> 3.0"])
  gem.add_development_dependency(%q<rake>, [">= 10.0.0"])
  gem.add_development_dependency(%q<vcr>, ["~> 6.0"])
  gem.add_development_dependency(%q<simplecov>, ["~> 0.7", ">= 0.7.0"])
  gem.add_development_dependency(%q<webmock>, ["~> 3.0"])
end
