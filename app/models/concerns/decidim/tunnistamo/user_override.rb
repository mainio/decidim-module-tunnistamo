# frozen_string_literal: true

module Decidim
  module Tunnistamo
    module UserOverride
      extend ActiveSupport::Concern

      included do
        def send_confirmation_notification?
          confirmation_required? && !@skip_confirmation_notification && self.email.present?
        end
      end
    end
  end
end
