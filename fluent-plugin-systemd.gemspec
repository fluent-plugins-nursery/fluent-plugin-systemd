lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "fluent-plugin-systemd"
  spec.version       = "0.0.11"
  spec.authors       = ["Ed Robinson"]
  spec.email         = ["ed@reevoo.com"]

  spec.summary       = "Input plugin to read from systemd journal."
  spec.description   = "This is a fluentd input plugin. It reads logs from the systemd journal."
  spec.homepage      = "https://github.com/reevoo/fluent-plugin-systemd"
  spec.license       = "MIT"


  spec.files         = Dir["lib/**/**.rb", "README.md", "LICENCE"]
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.10"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "reevoocop"
  spec.add_development_dependency "test-unit", "~> 2.5"

  spec.add_runtime_dependency "fluentd", "~> 0.12"
  spec.add_runtime_dependency "systemd-journal", "~> 1.3.2"
end
