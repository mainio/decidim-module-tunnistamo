# frozen_string_literal: true

module Decidim
  module Tunnistamo
    module CreateOmniauthRegistrationOverride
      extend ActiveSupport::Concern

      included do
        alias_method :verify_user_confirmed_orig_tunnistamo, :verify_user_confirmed unless private_method_defined?(:verify_user_confirmed_orig_tunnistamo)

        # Tunnistamo customization to the create or find user.
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

      # Original method from Decidim to add the unscoped to the user search.
      def create_or_find_user_orig_tunnistamo
        @user = User.unscoped.find_or_initialize_by(
          email: verified_email,
          organization: organization
        )

        if @user.persisted?
          # If user has left the account unconfirmed and later on decides to sign
          # in with omniauth with an already verified account, the account needs
          # to be marked confirmed.
          @user.skip_confirmation! if !@user.confirmed? && @user.email == verified_email
        else
          generated_password = SecureRandom.hex

          @user.email = (verified_email || form.email)
          @user.name = form.name
          @user.nickname = form.normalized_nickname
          @user.newsletter_notifications_at = nil
          @user.password = generated_password
          @user.password_confirmation = generated_password
          if form.avatar_url.present?
            url = URI.parse(form.avatar_url)
            filename = File.basename(url.path)
            file = url.open
            @user.avatar.attach(io: file, filename: filename)
          end
          @user.skip_confirmation! if verified_email
        end

        @user.tos_agreement = "1"
        @user.save!
      end
    end
  end
end
