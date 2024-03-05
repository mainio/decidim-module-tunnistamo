# frozen_string_literal: true

require "decidim/dev"

ENV["RAILS_ENV"] ||= "test"

require "simplecov" if ENV["SIMPLECOV"]

require "decidim/core"
require "decidim/core/test"
require "decidim/admin/test"

require "decidim/dev/test/rspec_support/component"
require "decidim/dev/test/rspec_support/authorization"

require "decidim/dev/test/base_spec_helper"

# This re-registration is made because of problems with chromedriver v120.
# Selenium methods are undefined without this change.
# See: https://github.com/decidim/decidim/pull/12160
require "#{ENV.fetch("ENGINE_ROOT")}/lib/decidim/tunnistamo/test/rspec_support/capybara"
