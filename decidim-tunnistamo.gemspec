# frozen_string_literal: true

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "decidim/tunnistamo/version"

Gem::Specification.new do |spec|
  spec.name = "decidim-tunnistamo"
  spec.version = Decidim::Tunnistamo.version
  spec.required_ruby_version = ">= 2.7"
  spec.authors = ["Antti Hukkanen"]
  spec.email = ["antti.hukkanen@mainiotech.fi"]

  spec.summary = "Provides possibility to bind Tunnistamo authentication provider to Decidim."
  spec.description = "Adds Tunnistamo authentication provider to Decidim."
  spec.homepage = "https://github.com/mainio/decidim-module-tunnistamo"
  spec.license = "AGPL-3.0"

  spec.files = Dir[
    "{app,config,lib}/**/*",
    "LICENSE-AGPLv3.txt",
    "Rakefile",
    "README.md"
  ]

  spec.require_paths = ["lib"]

  spec.add_dependency "decidim-core", Decidim::Tunnistamo.decidim_version
  spec.add_dependency "omniauth-tunnistamo", "~> 0.2.0"

  spec.add_development_dependency "decidim-dev", Decidim::Tunnistamo.decidim_version
end
