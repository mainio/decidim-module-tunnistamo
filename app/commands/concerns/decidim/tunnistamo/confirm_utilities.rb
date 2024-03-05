# frozen_string_literal: true

module Decidim
  module Tunnistamo
    module ConfirmUtilities
      private

      def switch_user_and_delete_temp_user!(existing_user, temp_user)
        update_identity_and_authorization!(temp_user, existing_user)
        existing_user.confirm
        existing_user.save!
        bypass_sign_in(existing_user)
        temp_user.destroy
      end

      def email_taken?
        another_user_with_same_email && another_user_with_same_email.id != user.id
      end

      def conflicting_identity_or_authorization
        return false unless another_user_with_same_email

        Decidim::Identity.find_by(provider: "tunnistamo", user: another_user_with_same_email).present? ||
          Decidim::Authorization.find_by(name: "tunnistamo_idp", user: another_user_with_same_email).present?
      end

      def update_identity_and_authorization!(temp_user, existing_user)
        Decidim::Identity.find_by(provider: "tunnistamo", user: temp_user).update!(user: existing_user)
        Decidim::Authorization.find_by(name: "tunnistamo_idp", user: temp_user).update!(user: existing_user)
      end

      def another_user_with_same_email
        @another_user_with_same_email ||= begin
          another_user = UserFinder.find_by(email: user.tunnistamo_email_sent_to, organization: form.current_organization)
          if another_user && another_user.id == user.id
            false
          else
            another_user
          end
        end
      end
    end
  end
end
