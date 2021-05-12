# frozen_string_literal: true

require "spec_helper"
require "rails/generators"
require "generators/decidim/tunnistamo/install_generator"

describe Decidim::Tunnistamo::Generators::InstallGenerator do
  let(:options) { {} }

  before { allow(subject).to receive(:options).and_return(options) }

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
      expect(File).to receive(:read).and_return(secrets_yml)
      expect(File).to receive(:readlines).and_return(secrets_yml.lines)
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
        expect(YAML).to receive(:safe_load).and_return(
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
end
