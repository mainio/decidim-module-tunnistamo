# Decidim::Tunnistamo

[![Build Status](https://github.com/mainio/decidim-module-tunnistamo/actions/workflows/ci_tunnistamo.yml/badge.svg)](https://github.com/mainio/decidim-module-tunnistamo/actions)
[![codecov](https://codecov.io/gh/mainio/decidim-module-tunnistamo/branch/master/graph/badge.svg)](https://codecov.io/gh/mainio/decidim-module-tunnistamo)

A [Decidim](https://github.com/decidim/decidim) module to add
[Tunnistamo](https://github.com/City-of-Helsinki/tunnistamo) authentication to
Decidim as a way to authenticate and authorize the users.

Tunnistamo is an SSO solution primarily for the public sector originally
developed by the City of Helsinki. It is also used by other cities in Finland.

The gem has been developed by [Mainio Tech](https://www.mainiotech.fi/).

The development has been sponsored by the
[City of Helsinki](https://www.hel.fi/) and
[City of Turku](https://www.turku.fi/).

## Preparation

Please refer to the
[`omniauth-tunnistamo`](https://github.com/mainio/omniauth-tunnistamo)
documentation in order to learn more about the preparation and getting started
with Tunnistamo.

## Installation

Add this line to your application's Gemfile:

```ruby
gem "decidim-tunnistamo"
```

And then execute:

```bash
$ bundle
```

After installation, you can add the configurations and necessary view extensions
by running the following command:

```bash
$ bundle exec rails generate decidim:tunnistamo:install
```

The install generator will also enable the Tunnistamo authentication method for
OmniAuth by default by adding these lines your `config/secrets.yml`:

```yml
default: &default
  # ...
  omniauth:
    # ...
    tunnistamo:
      enabled: false
      server_uri: <%= ENV["OMNIAUTH_TUNNISTAMO_SERVER_URI"] %>
      client_id: <%= ENV["OMNIAUTH_TUNNISTAMO_CLIENT_ID"] %>
      client_secret: <%= ENV["OMNIAUTH_TUNNISTAMO_CLIENT_SECRET"] %>
      icon: account-login
development:
  # ...
  omniauth:
    # ...
    tunnistamo:
      enabled: true
      server_uri: <%= ENV["OMNIAUTH_TUNNISTAMO_SERVER_URI"] %>
      client_id: <%= ENV["OMNIAUTH_TUNNISTAMO_CLIENT_ID"] %>
      client_secret: <%= ENV["OMNIAUTH_TUNNISTAMO_CLIENT_SECRET"] %>
      icon: account-login
```

This will enable the Tunnistamo authentication for the development environment
only. In case you want to enable it for other environments as well, apply the
OmniAuth configuration keys accordingly to other environments as well.

The example configuration will set the `account-login` icon for the the
authentication button from the Decidim's own iconset. In case you want to have a
better and more formal styling for the sign in button, you will need to
customize the sign in / sign up views.

The install generator will add an extension to your
`app/views/layouts/decidim/_head_extra.html.erb` partial in order to control
the sign out flow for Tunnistamo. This file will be created if it does not yet
exist or it will be modified if it already exists. This has to be done through
a separate request using JavaScript because Tunnistamo does not currently
implement sign out redirection which would make the user experience much worse
leaving the user in the Tunnistamo sign in page after a successful sign out.

## Usage

This gem providers two things:

1. Tunnistamo OmniAuth provider in order to sign in with Tunnistamo.
2. Tunnistamo authorization in order to authorize users using the Tunnistamo
   user profile data.

To enable these, you need to sign in to the Decidim system management panel.
After enabled from there, you can start using them.

Using the Tunnistamo OmniAuth sign in method will automatically authorize the
users during their sign ins. This way they don't have to separately sign in and
authorize themselves using the same identity provider.

## Customization

For some specific needs, you may need to store extra metadata for the Tunnistamo
authorization or add new authorization configuration options for the
authorization.

This can be achieved by applying the following configuration to the module
inside the initializer described above:

```ruby
# config/initializers/tunnistamo.rb

Decidim::Tunnistamo.configure do |config|
  # ... keep the default configuration as is ...
  # Add this extra configuration:
  config.workflow_configurator = lambda do |workflow|
    # When expiration is set to 0 minutes, it will never expire.
    workflow.expires_in = 0.minutes
    workflow.action_authorizer = "CustomTunnistamoActionAuthorizer"
    workflow.options do |options|
      options.attribute :custom_option, type: :string, required: false
    end
  end
  config.metadata_collector_class = CustomTunnistamoMetadataCollector
  config.strong_identity_providers = ["custom_strong_provider"]
end
```

For the workflow configuration options, please refer to the
[decidim-verifications documentation](https://github.com/decidim/decidim/tree/master/decidim-verifications).

For the custom metadata collector, please extend the default class as follows:

```ruby
# frozen_string_literal: true

class CustomTunnistamoMetadataCollector < Decidim::Tunnistamo::Verification::MetadataCollector
  def metadata
    super.tap do |data|
      # You can access the OAuth raw info attributes using the `raw_info`
      # accessor:
      data[:extra] = raw_info[:extra_data]
    end
  end
end
```

## Contributing

See [Decidim](https://github.com/decidim/decidim).

### Testing

To run the tests run the following in the gem development path:

```bash
$ bundle
$ DATABASE_USERNAME=<username> DATABASE_PASSWORD=<password> bundle exec rake test_app
$ DATABASE_USERNAME=<username> DATABASE_PASSWORD=<password> bundle exec rspec
```

Note that the database user has to have rights to create and drop a database in
order to create the dummy test app database.

In case you are using [rbenv](https://github.com/rbenv/rbenv) and have the
[rbenv-vars](https://github.com/rbenv/rbenv-vars) plugin installed for it, you
can add these environment variables to the root directory of the project in a
file named `.rbenv-vars`. In this case, you can omit defining these in the
commands shown above.

### Test code coverage

If you want to generate the code coverage report for the tests, you can use
the `SIMPLECOV=1` environment variable in the rspec command as follows:

```bash
$ SIMPLECOV=1 bundle exec rspec
```

This will generate a folder named `coverage` in the project root which contains
the code coverage report.

### Localization

If you would like to see this module in your own language, you can help with its
translation at Crowdin:

https://crowdin.com/project/decidim-tunnistamo

## License

See [LICENSE-AGPLv3.txt](LICENSE-AGPLv3.txt).
