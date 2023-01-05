# frozen_string_literal: true

require "spec_helper"
require "rails/generators"
require "generators/decidim/tunnistamo/install_generator"

describe Decidim::Tunnistamo::Generators::InstallGenerator do
  let(:options) { {} }

  # rubocop:disable Rspec/SubjectStub
  before { allow(subject).to receive(:options).and_return(options) }

  describe "#append_tunnistamo_sign_out_iframe" do
    let(:tunnistamo_line) { '<%= render partial: "decidim/tunnistamo/shared/tunnistamo_sign_out" %>' }
    let(:layout_dir) { Rails.application.root.join("app/views/layouts/decidim") }
    let(:head_extra_file) { layout_dir.join("_head_extra.html.erb") }

    it "when file does not exist creates file" do
      allow(File).to receive(:readlines).and_return([])
      expect(File).to receive(:open).with(anything, "a+") do |&block|
        file = double
        expect(file).to receive(:write).with(tunnistamo_line)
        expect(file).to receive(:write).with("\n")
        block.call(file)
      end

      subject.append_tunnistamo_sign_out_iframe
    end

    it "when the file exist say status identical" do
      allow(File).to receive(:readlines).and_return([tunnistamo_line])
      expect(subject).to receive(:say_status).with(
        :identical,
        "app/views/layouts/decidim/_head_extra.html.erb",
        :blue
      )

      subject.append_tunnistamo_sign_out_iframe
    end
  end

  describe "#enable_authentication" do
    let(:secrets_yml_template) do
      yml = "default: &default\n"
      yml += "  omniauth:\n"
      yml += "    facebook:\n"
      yml += "      enabled: false\n"
      yml += "      app_id: 1234\n"
      yml += "      app_secret: 4567\n"
      yml += "%TUNNISTAMO_INJECTION_DEFAULT%"
      yml += "  geocoder:\n"
      yml += "    here_app_id: 1234\n"
      yml += "    here_app_code: 1234\n"
      yml += "\n"
      yml += "development:\n"
      yml += "  <<: *default\n"
      yml += "  secret_key_base: aaabbb\n"
      yml += "  omniauth:\n"
      yml += "    developer:\n"
      yml += "      enabled: true\n"
      yml += "      icon: phone\n"
      yml += "%TUNNISTAMO_INJECTION_DEVELOPMENT%"
      yml += "\n"
      yml += "test:\n"
      yml += "  <<: *default\n"
      yml += "  secret_key_base: cccddd\n"
      yml += "\n"

      yml
    end

    let(:secrets_yml) do
      secrets_yml_template.gsub(
        /%TUNNISTAMO_INJECTION_DEFAULT%/,
        ""
      ).gsub(
        /%TUNNISTAMO_INJECTION_DEVELOPMENT%/,
        ""
      )
    end

    let(:secrets_yml_modified) do
      default = "    tunnistamo:\n"
      default += "      enabled: false\n"
      default += "      server_uri: <%= ENV[\"OMNIAUTH_TUNNISTAMO_SERVER_URI\"] %>\n"
      default += "      client_id: <%= ENV[\"OMNIAUTH_TUNNISTAMO_CLIENT_ID\"] %>\n"
      default += "      client_secret: <%= ENV[\"OMNIAUTH_TUNNISTAMO_CLIENT_SECRET\"] %>\n"
      default += "      icon: account-login\n"
      development = "    tunnistamo:\n"
      development += "      enabled: true\n"
      development += "      server_uri: <%= ENV[\"OMNIAUTH_TUNNISTAMO_SERVER_URI\"] %>\n"
      development += "      client_id: <%= ENV[\"OMNIAUTH_TUNNISTAMO_CLIENT_ID\"] %>\n"
      development += "      client_secret: <%= ENV[\"OMNIAUTH_TUNNISTAMO_CLIENT_SECRET\"] %>\n"
      development += "      icon: account-login\n"

      secrets_yml_template.gsub(
        /%TUNNISTAMO_INJECTION_DEFAULT%/,
        default
      ).gsub(
        /%TUNNISTAMO_INJECTION_DEVELOPMENT%/,
        development
      )
    end

    it "enables the Tunnistamo authentication by modifying the secrets.yml file" do
      allow(File).to receive(:read).and_return(secrets_yml)
      allow(File).to receive(:readlines).and_return(secrets_yml.lines)
      expect(File).to receive(:open).with(anything, "w") do |&block|
        file = double
        expect(file).to receive(:puts).with(secrets_yml_modified)
        block.call(file)
      end
      expect(subject).to receive(:say_status).with(
        :insert,
        "config/secrets.yml",
        :green
      )

      subject.enable_authentication
    end

    context "with Tunnistamo already enabled" do
      it "reports identical status" do
        allow(YAML).to receive(:safe_load).and_return(
          "default" => { "omniauth" => { "tunnistamo" => {} } }
        )
        expect(subject).to receive(:say_status).with(
          :identical,
          "config/secrets.yml",
          :blue
        )

        subject.enable_authentication
      end
    end
  end
  # rubocop:enable Rspec/SubjectStub
end
