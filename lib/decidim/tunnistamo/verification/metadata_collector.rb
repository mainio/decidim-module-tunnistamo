# frozen_string_literal: true

module Decidim
  module Tunnistamo
    module Verification
      class MetadataCollector
        def initialize(raw_info)
          @raw_info = raw_info
        end

        def metadata
          {
            service: authentication_method,
            name: raw_info[:name],
            given_name: raw_info[:given_name],
            family_name: raw_info[:family_name]
          }
        end

        # Digested format of the person's identifier unique to the person.
        # Note that Tunnistamo may generate different identifiers for different
        # authentication methods for the same person.
        #
        # The "sub" referes to the OpenID subject. This is what the spec says
        # about the subject:
        #   "Locally unique and never reassigned identifier within the Issuer
        #   for the End-User, which is intended to be consumed by the Client."
        def person_identifier_digest
          @person_identifier_digest ||= Digest::MD5.hexdigest(
            "#{raw_info[:sub]}:#{Rails.application.secrets.secret_key_base}"
          )
        end

        protected

        attr_reader :raw_info

        def authentication_method
          # Authentication Method Reference (amr)
          raw_info[:amr]
        end
      end
    end
  end
end
