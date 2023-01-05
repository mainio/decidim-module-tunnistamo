# frozen_string_literal: true

require "rails/generators/base"

module Decidim
  module Tunnistamo
    module Generators
      class InstallGenerator < Rails::Generators::Base
        source_root File.expand_path("../../templates", __dir__)

        desc "Modifies the secrets.yml configuration file for Tunnistamo."

        class_option(
          :test_initializer,
          desc: "Copies the test initializer instead of the actual one (for test dummy app).",
          type: :boolean,
          default: false,
          hide: true
        )

        def copy_initializer
          copy_file "tunnistamo_initializer_test.rb", "config/initializers/tunnistamo.rb" if options[:test_initializer]
        end

        def enable_authentication
          secrets_path = Rails.application.root.join("config", "secrets.yml")
          evaluated_secrets = ERB.new(File.read(secrets_path))
          secrets = YAML.safe_load(evaluated_secrets.result, [], [], true)

          if secrets["default"]["omniauth"]["tunnistamo"]
            say_status :identical, "config/secrets.yml", :blue
          else
            mod = SecretsModifier.new(secrets_path)
            final = mod.modify

            target_path = Rails.application.root.join("config", "secrets.yml")
            File.open(target_path, "w") { |f| f.puts final }

            say_status :insert, "config/secrets.yml", :green
          end
        end

        def append_tunnistamo_sign_out_iframe
          layout_dir = Rails.application.root.join("app/views/layouts/decidim")
          FileUtils.mkdir_p(layout_dir) unless File.directory?(layout_dir)

          head_extra_file = layout_dir.join("_head_extra.html.erb")
          unless File.exist?(head_extra_file)
            FileUtils.touch(head_extra_file)
            say_status :create, "app/views/layouts/decidim/_head_extra.html.erb", :green
          end

          tunnistamo_line = '<%= render partial: "decidim/tunnistamo/shared/tunnistamo_sign_out" %>'
          if File.readlines(head_extra_file).grep(/^#{tunnistamo_line}$/).size.positive?
            say_status :identical, "app/views/layouts/decidim/_head_extra.html.erb", :blue
            return
          end

          File.open(head_extra_file, "a+") do |f|
            f.write("\n")
            f.write(tunnistamo_line)
          end
          say_status :insert, "app/views/layouts/decidim/_head_extra.html.erb", :green
        end

        class SecretsModifier
          def initialize(filepath)
            @filepath = filepath
          end

          def modify
            self.inside_config = false
            self.inside_omniauth = false
            self.config_branch = nil
            @final = ""

            @empty_line_count = 0
            File.readlines(filepath).each do |line|
              if line =~ /^$/
                @empty_line_count += 1
                next
              else
                handle_line line
                insert_empty_lines
              end

              @final += line
            end
            insert_empty_lines

            @final
          end

          private

          attr_accessor :filepath, :empty_line_count, :inside_config, :inside_omniauth, :config_branch

          def handle_line(line)
            if inside_config && line =~ /^  omniauth:/
              self.inside_omniauth = true
            elsif inside_omniauth && (line =~ /^(  )?[a-z]+/ || line =~ /^#.*/)
              inject_tunnistamo_config
              self.inside_omniauth = false
            end

            return unless line =~ /^[a-z]+/

            # A new root configuration block starts
            self.inside_config = false
            self.inside_omniauth = false

            case line
            when /^default:/
              self.inside_config = true
              self.config_branch = :default
            when /^development:/
              self.inside_config = true
              self.config_branch = :development
            when /^test:/
              self.inside_config = true
              self.config_branch = :test
            end
          end

          def insert_empty_lines
            @final += "\n" * empty_line_count
            @empty_line_count = 0
          end

          def inject_tunnistamo_config
            @final += "    tunnistamo:\n"
            @final += if [:development, :test].include?(config_branch)
                        "      enabled: true\n"
                      else
                        "      enabled: false\n"
              end

            @final += "      server_uri: <%= ENV[\"OMNIAUTH_TUNNISTAMO_SERVER_URI\"] %>\n"
            @final += "      client_id: <%= ENV[\"OMNIAUTH_TUNNISTAMO_CLIENT_ID\"] %>\n"
            @final += "      client_secret: <%= ENV[\"OMNIAUTH_TUNNISTAMO_CLIENT_SECRET\"] %>\n"
            @final += "      icon: account-login\n"
          end
        end
      end
    end
  end
end
