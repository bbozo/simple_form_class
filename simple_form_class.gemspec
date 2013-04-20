# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'simple_form_class/version'

Gem::Specification.new do |spec|
  spec.name          = "simple_form_class"
  spec.version       = SimpleFormClass::VERSION
  spec.authors       = ["Borna Novak"]
  spec.email         = ["dosadnizub@gmail.com"]
  spec.description   = %q{An implementation of the form class pattern, for controller use}
  spec.summary       = %q{Rails model validators when used in forms are a clear break of MVC architecture and strong_parameters make things unDRY, this is one take on making things be Better}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency 'activemodel', '>= 3.0'
  spec.add_dependency 'activerecord', '>= 3.0'

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "pry-rails"
end
