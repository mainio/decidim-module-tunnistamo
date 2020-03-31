# frozen_string_literal: true

module Decidim
  module Tunnistamo
    module Authentication
      class Authenticator
        include ActiveModel::Validations

        def initialize(organization, oauth_hash)
          @organization = organization
          @oauth_hash = oauth_hash
        end

        def verified_email
          @verified_email ||= begin
            email = oauth_data.dig(:info, :email)
            if email
              email
            else
              domain = Decidim::Tunnistamo.auto_email_domain || organization.host
              "tunnistamo-#{person_identifier_digest}@#{domain}"
            end
          end
        end

        # Private: Create form params from omniauth hash
        # Since we are using trusted omniauth data we are generating a valid signature.
        def user_params_from_oauth_hash
          return nil if oauth_data.empty?
          return nil if user_identifier.blank?

          {
            provider: oauth_data[:provider],
            uid: user_identifier,
            name: user_full_name,
            # The nickname is automatically "parametrized" by Decidim core from
            # the name string, i.e. it will be in correct format.
            nickname: oauth_nickname,
            oauth_signature: user_signature,
            avatar_url: oauth_data[:info][:image],
            raw_data: oauth_hash
          }
        end

        def validate!
          raise ValidationError, "Invalid person dentifier" if person_identifier_digest.blank?

          true
        end

        def identify_user!(user)
          identity = user.identities.find_by(
            organization: organization,
            provider: oauth_data[:provider],
            uid: user_identifier
          )
          unless identity.user
            identity.destroy!
            identity = nil
          end

          return identity if identity

          # Check that the identity is not already bound to another user.
          id = Decidim::Identity.find_by(
            organization: organization,
            provider: oauth_data[:provider],
            uid: user_identifier
          )

          raise IdentityBoundToOtherUserError if id

          user.identities.create!(
            organization: organization,
            provider: oauth_data[:provider],
            uid: user_identifier
          )
        end

        def authorize_user!(user)
          authorization = Decidim::Authorization.find_by(
            name: "tunnistamo_idp",
            unique_id: user_signature
          )
          if authorization
            raise AuthorizationBoundToOtherUserError if authorization.user != user
          else
            authorization = Decidim::Authorization.find_or_initialize_by(
              name: "tunnistamo_idp",
              user: user
            )
          end

          authorization.attributes = {
            unique_id: user_signature,
            metadata: authorization_metadata
          }
          authorization.save!

          # This will update the "granted_at" timestamp of the authorization which
          # will postpone expiration on re-authorizations in case the
          # authorization is set to expire (by default it will not expire).
          authorization.grant!

          authorization
        end

        protected

        attr_reader :organization, :oauth_hash

        def oauth_data
          @oauth_data ||= oauth_hash.slice(:provider, :uid, :info)
        end

        # The Tunnistamo's assigned UID for the person.
        def user_identifier
          @user_identifier ||= oauth_data[:uid]
        end

        # Create a unique signature for the user that will be used for the
        # granted authorization.
        def user_signature
          @user_signature ||= ::Decidim::OmniauthRegistrationForm.create_signature(
            oauth_data[:provider],
            user_identifier
          )
        end

        def user_full_name
          return oauth_data[:info][:name] if oauth_data[:info][:name]

          @user_full_name ||= begin
            first_name = oauth_raw_info[:given_name] || oauth_raw_info[:first_name]
            last_name = oauth_raw_info[:last_name]

            "#{first_name} #{last_name}"
          end
        end

        def oauth_name
          oauth_data.dig(:info, :name) || oauth_nickname || verified_email.split("@").first
        end

        def oauth_nickname
          # Fetch the nickname passed form Tunnistamo
          oauth_data.dig(:info, :nickname) || oauth_raw_info.dig(:nickname)
        end

        def metadata_collector
          @metadata_collector ||= Decidim::Tunnistamo::Verification::Manager.metadata_collector_for(
            oauth_raw_info
          )
        end

        # Data that is stored against the authorization "permanently" (i.e. as
        # long as the authorization is valid).
        def authorization_metadata
          metadata_collector.metadata
        end

        # The digest that is created from the person identifier.
        def person_identifier_digest
          metadata_collector.person_identifier_digest
        end

        def oauth_raw_info
          oauth_hash.dig(:extra, :raw_info) || {}
        end
      end
    end
  end
end
