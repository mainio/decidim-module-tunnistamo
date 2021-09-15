# frozen_string_literal: true

require "decidim/dev/common_rake"

def install_module(path)
  Dir.chdir(path) do
    system("bundle exec rails generate decidim:tunnistamo:install --test-initializer true")
    system("bundle exec rake decidim_tunnistamo:install:migrations")
    system("bundle exec rake db:migrate")
  end
end

desc "Generates a dummy app for testing"
task test_app: "decidim:generate_external_test_app" do
  ENV["RAILS_ENV"] = "test"
  install_module("spec/decidim_dummy_app")
end

desc "Generates a development app."
task development_app: "decidim:generate_external_development_app" do
  Dir.chdir("development_app") do
    system("bundle exec rails generate decidim:tunnistamo:install")
  end
  install_module("development_app")
end
