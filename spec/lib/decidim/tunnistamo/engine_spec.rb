# frozen_string_literal: true

require "spec_helper"

describe Decidim::Tunnistamo::Engine do
  it "mounts the routes to the core engine" do
    routes = double
    expect(Decidim::Core::Engine).to receive(:routes).and_return(routes)
    expect(routes).to receive(:prepend) do |&block|
      context = double
      expect(context).to receive(:mount).with(described_class => "/")
      context.instance_eval(&block)
    end

    run_initializer("decidim_tunnistamo.mount_routes")
  end

  it "adds the correct routes to the core engine" do
    run_initializer("decidim_tunnistamo.mount_routes")

    %w(GET POST).each do |method|
      expect(
        Decidim::Core::Engine.routes.recognize_path(
          "/users/auth/tunnistamo",
          method: method
        )
      ).to eq(
        controller: "decidim/tunnistamo/omniauth_callbacks",
        action: "passthru"
      )
      expect(
        Decidim::Core::Engine.routes.recognize_path(
          "/users/auth/tunnistamo/callback",
          method: method
        )
      ).to eq(
        controller: "decidim/tunnistamo/omniauth_callbacks",
        action: "tunnistamo"
      )
    end
  end

  it "configures the Tunnistamo omniauth strategy for Devise" do
    expect(Devise).to receive(:setup) do |&block|
      cs = Decidim::Tunnistamo::Test::Runtime.cert_store

      config = double
      expect(config).to receive(:omniauth).with(
        :tunnistamo,
        mode: :test
      )
      block.call(config)
    end

    run_initializer("decidim_tunnistamo.setup")
  end

  it "configures the OmniAuth failure app" do
    expect(OmniAuth.config).to receive(:on_failure=) do |proc|
      env = double
      action = double
      expect(env).to receive(:[]).with("PATH_INFO").and_return(
        "/users/auth/tunnistamo"
      )
      expect(env).to receive(:[]=).with("devise.mapping", ::Devise.mappings[:user])
      expect(Decidim::Tunnistamo::OmniauthCallbacksController).to receive(
        :action
      ).with(:failure).and_return(action)
      expect(action).to receive(:call).with(env)

      proc.call(env)
    end

    run_initializer("decidim_tunnistamo.setup")
  end

  it "falls back on the default OmniAuth failure app" do
    failure_app = double

    expect(OmniAuth.config).to receive(:on_failure).and_return(failure_app)
    expect(OmniAuth.config).to receive(:on_failure=) do |proc|
      env = double
      expect(env).to receive(:[]).with("PATH_INFO").and_return(
        "/something/else"
      )
      expect(failure_app).to receive(:call).with(env)

      proc.call(env)
    end

    run_initializer("decidim_tunnistamo.setup")
  end

  it "calls the add_omniauth_provider method correctly" do
    expect(described_class).to receive(:add_omniauth_provider)
    expect(ActiveSupport::Reloader).to receive(:to_run) do |&block|
      expect(described_class).to receive(:add_omniauth_provider)
      block.call
    end

    run_initializer("decidim_tunnistamo.omniauth_provider")
  end

  it "adds the mail interceptor" do
    expect(ActionMailer::Base).to receive(:register_interceptor).with(
      Decidim::Tunnistamo::MailInterceptors::GeneratedRecipientsInterceptor
    )

    run_initializer("decidim_tunnistamo.mail_interceptors")
  end

  describe "#add_omniauth_provider" do
    it "adds the :tunnistamo OmniAuth provider" do
      # Reset the constant
      original_providers = [:facebook, :twitter, :google_oauth2]
      ::Decidim::User.send(:remove_const, :OMNIAUTH_PROVIDERS)
      ::Decidim::User.const_set(:OMNIAUTH_PROVIDERS, original_providers)

      expected = original_providers + [:tunnistamo]

      expect(::Decidim::User).to receive(:remove_const).once.with(
        :OMNIAUTH_PROVIDERS
      ).and_call_original
      expect(::Decidim::User).to receive(:const_set).once.with(
        :OMNIAUTH_PROVIDERS,
        expected
      ).and_call_original

      # Make sure that the constant monkey patch is only done once even when the
      # to_prepare hooks are run multiple times.
      described_class.add_omniauth_provider
      described_class.add_omniauth_provider

      expect(::Decidim::User::OMNIAUTH_PROVIDERS).to eq(expected)
    end
  end

  def run_initializer(initializer_name)
    config = described_class.initializers.find do |i|
      i.name == initializer_name
    end
    config.run
  end
end
