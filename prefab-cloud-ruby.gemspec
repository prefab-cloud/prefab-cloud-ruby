# Generated by juwelier
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Juwelier::Tasks in Rakefile, and run 'rake gemspec'
# -*- encoding: utf-8 -*-
# stub: prefab-cloud-ruby 0.21.0 ruby lib

Gem::Specification.new do |s|
  s.name = "prefab-cloud-ruby".freeze
  s.version = "0.21.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Jeff Dwyer".freeze]
  s.date = "2023-03-08"
  s.description = "RateLimits & Config as a service".freeze
  s.email = "jdwyer@prefab.cloud".freeze
  s.extra_rdoc_files = [
    "LICENSE.txt",
    "README.md"
  ]
  s.files = [
    ".envrc",
    ".envrc.sample",
    ".github/workflows/ruby.yml",
    ".gitmodules",
    ".tool-versions",
    "CODEOWNERS",
    "Gemfile",
    "Gemfile.lock",
    "LICENSE.txt",
    "README.md",
    "Rakefile",
    "VERSION",
    "compile_protos.sh",
    "lib/prefab-cloud-ruby.rb",
    "lib/prefab/auth_interceptor.rb",
    "lib/prefab/cancellable_interceptor.rb",
    "lib/prefab/client.rb",
    "lib/prefab/config_client.rb",
    "lib/prefab/config_loader.rb",
    "lib/prefab/config_resolver.rb",
    "lib/prefab/config_value_unwrapper.rb",
    "lib/prefab/criteria_evaluator.rb",
    "lib/prefab/error.rb",
    "lib/prefab/errors/initialization_timeout_error.rb",
    "lib/prefab/errors/invalid_api_key_error.rb",
    "lib/prefab/errors/missing_default_error.rb",
    "lib/prefab/feature_flag_client.rb",
    "lib/prefab/internal_logger.rb",
    "lib/prefab/local_config_parser.rb",
    "lib/prefab/log_path_collector.rb",
    "lib/prefab/logger_client.rb",
    "lib/prefab/murmer3.rb",
    "lib/prefab/noop_cache.rb",
    "lib/prefab/noop_stats.rb",
    "lib/prefab/options.rb",
    "lib/prefab/ratelimit_client.rb",
    "lib/prefab/sse_logger.rb",
    "lib/prefab/weighted_value_resolver.rb",
    "lib/prefab/yaml_config_parser.rb",
    "lib/prefab_pb.rb",
    "lib/prefab_services_pb.rb",
    "prefab-cloud-ruby.gemspec",
    "test/.prefab.default.config.yaml",
    "test/.prefab.unit_tests.config.yaml",
    "test/integration_test.rb",
    "test/integration_test_helpers.rb",
    "test/test_client.rb",
    "test/test_config_client.rb",
    "test/test_config_loader.rb",
    "test/test_config_resolver.rb",
    "test/test_config_value_unwrapper.rb",
    "test/test_criteria_evaluator.rb",
    "test/test_feature_flag_client.rb",
    "test/test_helper.rb",
    "test/test_integration.rb",
    "test/test_local_config_parser.rb",
    "test/test_logger.rb",
    "test/test_weighted_value_resolver.rb"
  ]
  s.homepage = "http://github.com/prefab-cloud/prefab-cloud-ruby".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "3.2.32".freeze
  s.summary = "Prefab Ruby Infrastructure".freeze

  if s.respond_to? :specification_version then
    s.specification_version = 4
  end

  if s.respond_to? :add_runtime_dependency then
    s.add_runtime_dependency(%q<concurrent-ruby>.freeze, ["~> 1.0", ">= 1.0.5"])
    s.add_runtime_dependency(%q<faraday>.freeze, [">= 0"])
    s.add_runtime_dependency(%q<googleapis-common-protos-types>.freeze, [">= 0"])
    s.add_runtime_dependency(%q<google-protobuf>.freeze, [">= 0"])
    s.add_runtime_dependency(%q<grpc>.freeze, [">= 0"])
    s.add_runtime_dependency(%q<ld-eventsource>.freeze, [">= 0"])
    s.add_runtime_dependency(%q<uuid>.freeze, [">= 0"])
    s.add_development_dependency(%q<benchmark-ips>.freeze, [">= 0"])
    s.add_development_dependency(%q<bundler>.freeze, [">= 0"])
    s.add_development_dependency(%q<grpc-tools>.freeze, [">= 0"])
    s.add_development_dependency(%q<juwelier>.freeze, ["~> 2.4.9"])
    s.add_development_dependency(%q<rdoc>.freeze, [">= 0"])
    s.add_development_dependency(%q<simplecov>.freeze, [">= 0"])
  else
    s.add_dependency(%q<concurrent-ruby>.freeze, ["~> 1.0", ">= 1.0.5"])
    s.add_dependency(%q<faraday>.freeze, [">= 0"])
    s.add_dependency(%q<googleapis-common-protos-types>.freeze, [">= 0"])
    s.add_dependency(%q<google-protobuf>.freeze, [">= 0"])
    s.add_dependency(%q<grpc>.freeze, [">= 0"])
    s.add_dependency(%q<ld-eventsource>.freeze, [">= 0"])
    s.add_dependency(%q<uuid>.freeze, [">= 0"])
    s.add_dependency(%q<benchmark-ips>.freeze, [">= 0"])
    s.add_dependency(%q<bundler>.freeze, [">= 0"])
    s.add_dependency(%q<grpc-tools>.freeze, [">= 0"])
    s.add_dependency(%q<juwelier>.freeze, ["~> 2.4.9"])
    s.add_dependency(%q<rdoc>.freeze, [">= 0"])
    s.add_dependency(%q<simplecov>.freeze, [">= 0"])
  end
end

