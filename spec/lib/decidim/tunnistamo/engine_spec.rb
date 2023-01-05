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
      config = double
      expect(config).to receive(:omniauth).with(
        :tunnistamo,
        {
          client_options: {
            host: "auth.tunnistamo-test.fi",
            identifier: "client_id",
            port: 443,
            redirect_uri: "http://localhost:3000/users/auth/tunnistamo/callback",
            scheme: "https",
            secret: "client_secret"
          },
          issuer: "https://auth.tunnistamo-test.fi/openid",
          post_logout_redirect_uri: "http://localhost:3000/users/auth/tunnistamo/post_logout",
          scope: [:openid, :email, :profile]
        }
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

  it "adds the mail interceptor" do
    expect(ActionMailer::Base).to receive(:register_interceptor).with(
      Decidim::Tunnistamo::MailInterceptors::GeneratedRecipientsInterceptor
    )

    run_initializer("decidim_tunnistamo.mail_interceptors")
  end

  def run_initializer(initializer_name)
    config = described_class.initializers.find do |i|
      i.name == initializer_name
    end
    config.run
  end
end
