# frozen_string_literal: true

module Decidim
  module Tunnistamo
    module CreateOmniauthRegistrationOverride
      extend ActiveSupport::Concern

      included do
        alias_method :create_or_find_user_orig_tunnistamo, :create_or_find_user unless respond_to?(:create_or_find_user_orig_tunnistamo)
        alias_method :verify_user_confirmed_orig_tunnistamo, :verify_user_confirmed unless respond_to?(:verify_user_confirmed_orig_tunnistamo)

        def create_or_find_user
          create_or_find_user_orig_tunnistamo

          return unless Decidim::Tunnistamo.confirm_emails
          return if form.email_confirmed

          @user.confirmed_at = nil
          @user.unconfirmed_email = authenticator.digged_email
          @user.skip_confirmation_notification!
          @user.save!
          @user.send(:generate_confirmation_token!)
        end

        def verify_user_confirmed(user)
          return verify_user_confirmed_orig_tunnistamo(user) unless ::Decidim::Tunnistamo.confirm_emails
          return true if user.confirmed?

          false
        end
      end
    end
  end
end
