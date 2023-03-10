# frozen_string_literal: true

require_relative "lib/testlab_sdk_ruby/version"

Gem::Specification.new do |spec|
  spec.name = "testlab_sdk_ruby"
  spec.version = TestlabSdkRuby::VERSION
  spec.authors = [
    "Alison Martinez",
    "Chelsea Saunders",
    "Sarah Bunker",
    "Abbie Papka",
  ]
  spec.email = [""]

  spec.summary = "Client SDK for accessing TestLab A/B testing platform"

  spec.homepage = "https://github.com/TestL-ab"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.6.0"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = %w[
    lib/testlab_sdk_ruby.rb
    lib/testlab_sdk_ruby/testlab_client.rb
    lib/testlab_sdk_ruby/testlab_feature_logic.rb
    lib/testlab_sdk_ruby/version.rb
  ]

  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  spec.add_dependency "httparty"
  spec.add_dependency "rufus-scheduler"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
