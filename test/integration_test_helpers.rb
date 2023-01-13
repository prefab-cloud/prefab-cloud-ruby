# frozen_string_literal: true

module IntegrationTestHelpers
  SUBMODULE_PATH = 'test/prefab-cloud-integration-test-data'
  RAISE_IF_NO_TESTS_FOUND = ENV['PREFAB_INTEGRATION_TEST_RAISE'] == 'true'

  def self.find_integration_tests
    version = find_integration_test_version

    files = find_versioned_test_files(version)

    if files.none?
      message = "No integration tests found for version: #{version}"
      raise message if RAISE_IF_NO_TESTS_FOUND

      puts message

    end

    files
  end

  def self.find_integration_test_version
    File.read(File.join(SUBMODULE_PATH, 'version')).strip
  rescue StandardError => e
    puts "No version found for integration tests: #{e.message}"
  end

  def self.find_versioned_test_files(version)
    if version.nil?
      []
    else
      Dir[File.join(SUBMODULE_PATH, "tests/#{version}/**/*")]
        .select { |file| file =~ /\.ya?ml$/ }
    end
  end
end
