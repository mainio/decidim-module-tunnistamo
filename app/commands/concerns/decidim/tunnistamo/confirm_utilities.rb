# frozen_string_literal: true

module Decidim
  module Tunnistamo
    module ConfirmUtilities
      private

      def switch_user_and_delete_temp_user!(existing_user)
        update_identity_and_authorization!(user, existing_user)
        existing_user.confirm
        existing_user.save!
        bypass_sign_in(existing_user)
        user.destroy
      end

      def email_taken?
        find_user = Decidim::User.find_by(email: user.tunnistamo_email_sent_to, organization: user.organization)
        return true if find_user && find_user.id != user.id

        false
      end

      def update_identity_and_authorization!(temp_user, existing_user)
        Decidim::Identity.find_by(provider: "tunnistamo", user: temp_user, organization: form.current_organization).update!(user: existing_user)
        Decidim::Authorization.find_by(name: "tunnistamo_idp", user: temp_user).update!(user: existing_user)
      end
    end
  end
end
