# frozen_string_literal: true

module Decidim
  module Tunnistamo
    module Verification
      # This is an engine that performs user authorization.
      class Engine < ::Rails::Engine
        isolate_namespace Decidim::Tunnistamo::Verification

        paths["db/migrate"] = nil
        paths["lib/tasks"] = nil

        routes do
          resource :authorizations, only: [:new], as: :authorization

          root to: "authorizations#new"
        end

        initializer "decidim_tunnistamo.verification_workflow", after: :load_config_initializers do
          next unless Decidim::Tunnistamo.configured?

          # We cannot use the name `:tunnistamo` for the verification workflow
          # because otherwise the route namespace (decidim_tunnistamo) would
          # conflict with the main engine controlling the authentication flows.
          # The main problem that this would bring is that the root path for
          # this engine would not be found.
          Decidim::Verifications.register_workflow(:tunnistamo_idp) do |workflow|
            workflow.engine = Decidim::Tunnistamo::Verification::Engine

            Decidim::Tunnistamo::Verification::Manager.configure_workflow(workflow)
          end
        end

        def load_seed
          # Enable the `:tunnistamo_idp` authorization
          org = Decidim::Organization.first
          org.available_authorizations << :tunnistamo_idp
          org.save!
        end
      end
    end
  end
end
