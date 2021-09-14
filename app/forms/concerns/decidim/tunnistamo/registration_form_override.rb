# frozen_string_literal: true

module Decidim
  module Tunnistamo
    module RegistrationFormOverride
      extend ActiveSupport::Concern

      included do
        attribute :email_confirmed, Virtus::Attribute::Boolean, default: true
      end
    end
  end
end
