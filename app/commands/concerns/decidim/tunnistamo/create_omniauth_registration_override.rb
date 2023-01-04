# frozen_string_literal: true

module Decidim
  module Tunnistamo
    module CreateOmniauthRegistrationOverride
      extend ActiveSupport::Concern

      included do
        alias_method :create_or_find_user_orig_tunnistamo, :create_or_find_user unless private_method_defined?(:create_or_find_user_orig_tunnistamo)
        alias_method :verify_user_confirmed_orig_tunnistamo, :verify_user_confirmed unless private_method_defined?(:verify_user_confirmed_orig_tunnistamo)

        def create_or_find_user
          create_or_find_user_orig_tunnistamo

          return if form.email_confirmed

          @user.confirmed_at = nil
          @user.unconfirmed_email = form.unconfirmed_email if form.unconfirmed_email.present?
          @user.skip_confirmation_notification!
          @user.save!
          @user.send(:generate_confirmation_token!)
        end

        def verify_user_confirmed(user)
          return verify_user_confirmed_orig_tunnistamo(user) unless ::Decidim::Tunnistamo.confirm_emails
          return true if user.confirmed?

          user.send(:generate_confirmation_token!) unless user.confirmation_token

          # If confirmation sent at is expired, user cant confirm new email (other than unconfirmed email from tunnistamo).
          # This is because Decidim's omniauth_registrations_controller.rb checks Devise's active_for_authentication?
          # after CreateOmniauthRegistration.
          user.update(confirmation_sent_at: Time.current) unless user.active_for_authentication?

          false
        end
      end
    end
  end
end