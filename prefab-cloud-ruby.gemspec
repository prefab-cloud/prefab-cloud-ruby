# frozen_string_literal: true

require_relative "lib/prefab-cloud-ruby"

Gem::Specification.new do |spec|
  spec.name = "prefab-cloud-ruby"
  spec.version = Prefab::VERSION
  spec.authors = ["Jeff Dwyer"]
  spec.email = ["jdwyer@prefab.cloud"]

  spec.summary = "Prefab Ruby Infrastructure"
  spec.description = "Feature Flags, Live Config, and Dynamic Log Levels as a service"
  spec.homepage = "http://github.com/prefab-cloud/prefab-cloud-ruby"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata["homepage_uri"] = spec.homepage

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) || f.start_with?(*%w[bin/ test/ spec/ features/ .git .circleci appveyor])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  if spec.respond_to? :add_runtime_dependency
    spec.add_runtime_dependency("concurrent-ruby", ["~> 1.0", ">= 1.0.5"])
    spec.add_runtime_dependency("faraday", [">= 0"])
    spec.add_runtime_dependency("googleapis-common-protos-types", [">= 0"])
    spec.add_runtime_dependency("google-protobuf", [">= 0"])
    spec.add_runtime_dependency("ld-eventsource", [">= 0"])
    spec.add_runtime_dependency("uuid", [">= 0"])
  else
    spec.add_dependency("concurrent-ruby", ["~> 1.0", ">= 1.0.5"])
    spec.add_dependency("faraday", [">= 0"])
    spec.add_dependency("googleapis-common-protos-types", [">= 0"])
    spec.add_dependency("google-protobuf", [">= 0"])
    spec.add_dependency("ld-eventsource", [">= 0"])
    spec.add_dependency("uuid", [">= 0"])
  end

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
