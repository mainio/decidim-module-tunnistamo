# frozen_string_literal: true

require "spec_helper"

module Decidim
  module Tunnistamo
    describe TokenConfirmationForm do
      subject { described_class.from_params(attributes).with_context(context) }

      let(:organization) { create(:organization) }
      let(:context) { { "current_organization" => organization } }
      let(:attributes) { { user_id: user.id, confirmation_token: param_token } }
      let!(:user) { create(:user, organization: organization, tunnistamo_email_code_sent_at: Time.current, confirmation_token: actual_token) }
      let(:actual_token) { Faker::Internet.unique.password }

      before do
        allow(subject).to receive(:current_user).and_return(user)
        allow(subject).to receive(:current_organization).and_return(organization)
      end

      context "when token is present" do
        let(:param_token) { actual_token }

        it { is_expected.to be_valid }
      end

      context "when token is missing" do
        let(:param_token) { nil }

        it do
          expect(subject).not_to be_valid
          expect(subject.errors[:token]).not_to be_empty
        end
      end

      context "when token doesnt match" do
        let(:param_token) { Faker::Internet.unique.password }

        it do
          expect(subject).not_to be_valid
          expect(subject.errors[:token]).not_to be_empty
        end
      end
    end
  end
end
