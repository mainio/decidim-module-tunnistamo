# frozen_string_literal: true

module Decidim
  module Tunnistamo
    class CodeConfirmationForm < Form
      attribute :email
      attribute :code
    end
  end
end
