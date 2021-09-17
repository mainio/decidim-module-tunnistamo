# frozen_string_literal: true

require "spec_helper"

module Decidim
  module Tunnistamo
    describe AskEmailForm do
      subject { described_class.from_params(attributes).with_context(context) }

      let(:organization) { create(:organization) }
      let(:context) { { "current_organization" => organization } }
      let(:attributes) { { email: email } }

      context "when email is present" do
        let(:email) { Faker::Internet.email }

        it { is_expected.to be_valid }
      end

      context "when email is missing" do
        let(:email) {}

        it { is_expected.to be_invalid }
      end
    end
  end
end
