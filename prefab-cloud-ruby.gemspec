# Generated by juwelier
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Juwelier::Tasks in Rakefile, and run 'rake gemspec'
# -*- encoding: utf-8 -*-
# stub: prefab-cloud-ruby 0.0.17 ruby lib

Gem::Specification.new do |s|
  s.name = "prefab-cloud-ruby".freeze
  s.version = "0.0.17"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Jeff Dwyer".freeze]
  s.date = "2018-03-12"
  s.description = "RateLimits & Config as a service".freeze
  s.email = "jdwyer@prefab.cloud".freeze
  s.extra_rdoc_files = [
    "LICENSE.txt"
  ]
  s.files = [
    ".ruby-version",
    "Gemfile",
    "Gemfile.lock",
    "LICENSE.txt",
    "Rakefile",
    "VERSION",
    "compile_protos.sh",
    "lib/prefab-cloud-ruby.rb",
    "lib/prefab/auth_interceptor.rb",
    "lib/prefab/client.rb",
    "lib/prefab/config_client.rb",
    "lib/prefab/config_loader.rb",
    "lib/prefab/config_resolver.rb",
    "lib/prefab/feature_flag_client.rb",
    "lib/prefab/logger_client.rb",
    "lib/prefab/murmer3.rb",
    "lib/prefab/noop_cache.rb",
    "lib/prefab/noop_stats.rb",
    "lib/prefab/ratelimit_client.rb",
    "lib/prefab_pb.rb",
    "lib/prefab_services_pb.rb",
    "prefab-cloud-ruby.gemspec",
    "test/.prefab.test.config.yaml",
    "test/test_config_loader.rb",
    "test/test_config_resolver.rb",
    "test/test_feature_flag_client.rb",
    "test/test_helper.rb",
    "test/test_logger.rb"
  ]
  s.homepage = "http://github.com/prefab-cloud/prefab-cloud-ruby".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "2.6.14".freeze
  s.summary = "Prefab Ruby Infrastructure".freeze

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<grpc>.freeze, ["~> 1.10.0"])
      s.add_runtime_dependency(%q<concurrent-ruby>.freeze, [">= 1.0.5", "~> 1.0"])
      s.add_development_dependency(%q<grpc-tools>.freeze, ["~> 1.10.0"])
      s.add_development_dependency(%q<shoulda>.freeze, [">= 0"])
      s.add_development_dependency(%q<rdoc>.freeze, ["~> 3.12"])
      s.add_development_dependency(%q<bundler>.freeze, ["~> 1.0"])
      s.add_development_dependency(%q<juwelier>.freeze, ["~> 2.1.0"])
      s.add_development_dependency(%q<simplecov>.freeze, [">= 0"])
    else
      s.add_dependency(%q<grpc>.freeze, ["~> 1.10.0"])
      s.add_dependency(%q<concurrent-ruby>.freeze, [">= 1.0.5", "~> 1.0"])
      s.add_dependency(%q<grpc-tools>.freeze, ["~> 1.10.0"])
      s.add_dependency(%q<shoulda>.freeze, [">= 0"])
      s.add_dependency(%q<rdoc>.freeze, ["~> 3.12"])
      s.add_dependency(%q<bundler>.freeze, ["~> 1.0"])
      s.add_dependency(%q<juwelier>.freeze, ["~> 2.1.0"])
      s.add_dependency(%q<simplecov>.freeze, [">= 0"])
    end
  else
    s.add_dependency(%q<grpc>.freeze, ["~> 1.10.0"])
    s.add_dependency(%q<concurrent-ruby>.freeze, [">= 1.0.5", "~> 1.0"])
    s.add_dependency(%q<grpc-tools>.freeze, ["~> 1.10.0"])
    s.add_dependency(%q<shoulda>.freeze, [">= 0"])
    s.add_dependency(%q<rdoc>.freeze, ["~> 3.12"])
    s.add_dependency(%q<bundler>.freeze, ["~> 1.0"])
    s.add_dependency(%q<juwelier>.freeze, ["~> 2.1.0"])
    s.add_dependency(%q<simplecov>.freeze, [">= 0"])
  end
end

