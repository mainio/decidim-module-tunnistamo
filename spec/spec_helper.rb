# frozen_string_literal: true

require "decidim/dev"
require "webmock"

require "decidim/tunnistamo/test/runtime"

require "simplecov" if ENV["SIMPLECOV"] || ENV["CODECOV"]
if ENV["CODECOV"]
  require "codecov"
  SimpleCov.formatter = SimpleCov::Formatter::Codecov
end

ENV["ENGINE_ROOT"] = File.dirname(__dir__)
ENV["OMNIAUTH_TUNNISTAMO_SERVER_URI"] = "https://auth.tunnistamo-test.fi"
ENV["OMNIAUTH_TUNNISTAMO_CLIENT_ID"] = "client_id"
ENV["OMNIAUTH_TUNNISTAMO_CLIENT_SECRET"] = "client_secret"

Decidim::Dev.dummy_app_path =
  File.expand_path(File.join(__dir__, "decidim_dummy_app"))

require_relative "base_spec_helper"

Decidim::Tunnistamo::Test::Runtime.initializer do
  # Silence the OmniAuth logger
  OmniAuth.config.logger = Logger.new("/dev/null")

  # Configure the Tunnistamo module
  Decidim::Tunnistamo.configure do |config|
    config.auto_email_domain = "1.lvh.me"
  end
end

Decidim::Tunnistamo::Test::Runtime.load_app

# Add the test templates path to ActionMailer
ActionMailer::Base.prepend_view_path(
  File.expand_path(File.join(__dir__, "fixtures", "mailer_templates"))
)

RSpec.configure do |config|
  # Make it possible to sign in and sign out the user in the request type specs.
  # This is needed because we need the request type spec for the omniauth
  # callback tests.
  config.include Devise::Test::IntegrationHelpers, type: :request

  config.before do
    # Respond to the metadata request with a stubbed request to avoid external
    # HTTP calls.
    # base_path = File.expand_path(File.join(__dir__, ".."))
    stub_request(
      :get,
      "https://auth.tunnistamo-test.fi/idp"
    ).to_return(status: 200, body: "RESPONSE", headers: {})
  end
end
