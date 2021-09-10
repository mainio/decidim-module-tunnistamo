# frozen_string_literal: true

module Decidim
  module Tunnistamo
    class EmailConfirmationForm < Form
      attribute :email

      validates :email, presence: true
    end
  end
end
