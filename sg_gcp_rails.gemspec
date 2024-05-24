# frozen_string_literal: true

require_relative "lib/sg_gcp_rails/version"

Gem::Specification.new do |spec|
  spec.name = "sg_gcp_rails"
  spec.version = SgGcpRails::VERSION
  spec.authors = ["ruzia"]
  spec.email = ["ruzia@sonicgarden.jp"]

  spec.summary = "Rails addon for Google Cloud."
  spec.homepage = "https://github.com/SonicGarden/sg_gcp_rails"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/SonicGarden/sg_gcp_rails"
  spec.metadata["changelog_uri"] = "https://github.com/SonicGarden/sg_gcp_rails/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "em-websocket", "~> 0.5.3"
  spec.add_dependency "http", "~> 5.2.0"
  spec.add_dependency "retryable", "~> 3.0.5"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
