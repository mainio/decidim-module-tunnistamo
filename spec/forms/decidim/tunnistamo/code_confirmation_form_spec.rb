# frozen_string_literal: true

require "spec_helper"

module Decidim
  module Tunnistamo
    describe CodeConfirmationForm do
      subject { described_class.from_params(attributes).with_context(context) }

      let(:organization) { create(:organization) }
      let(:context) { { "current_organization" => organization } }
      let(:attributes) { { code: param_code } }
      let!(:user) { create(:user, organization: organization, tunnistamo_email_code_sent_at: Time.current, tunnistamo_email_code: actual_code) }
      let(:actual_code) { rand(100_000..999_999).to_s }

      before do
        allow(subject).to receive(:current_user).and_return(user)
      end

      context "when code is present" do
        let(:param_code) { actual_code }

        it { is_expected.to be_valid }
      end

      context "when code is missing" do
        let(:param_code) {}

        it { is_expected.to be_invalid }
      end

      context "when code doesnt match" do
        let(:param_code) { "000100" }

        it { is_expected.to be_invalid }
      end
    end
  end
end
