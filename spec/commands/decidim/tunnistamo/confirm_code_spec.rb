# frozen_string_literal: true

require "spec_helper"

module Decidim::Tunnistamo
  describe ConfirmCode do
    subject { described_class.new(form, user) }

    let(:organization) { create(:organization) }
    let(:user) do
      create(
        :user,
        organization: organization,
        tunnistamo_email_sent_to: email,
        tunnistamo_email_code_sent_at: Time.current,
        tunnistamo_email_code: "123456"
      )
    end
    let(:form) do
      double(
        current_organization: organization,
        current_user: user,
        email: email,
        code_valid?: true,
        invalid?: invalid
      )
    end
    let(:email) { Faker::Internet.unique.email }
    let(:invalid) { false }

    let!(:identity) { create(:identity, user: user, provider: "tunnistamo", uid: SecureRandom.uuid) }
    let!(:authorization) { Decidim::Authorization.create(name: "tunnistamo_idp", user: user, granted_at: Time.current) }

    before do
      allow(subject).to receive(:bypass_sign_in).and_return(true)
    end

    context "when there is existing user with same email" do
      let!(:existing_user) { create(:user, email: email, organization: organization) }

      # TODO: What should happen if conflicting identities or authorizations
      # let!(:another_identity) { create(:identity, user: existing_user, provider: "tunnistamo", uid: SecureRandom.uuid) }
      # let!(:another_authorization) { Decidim::Authorization.create(name: "tunnistamo_idp", user: existing_user, granted_at: Time.current) }

      it "switches authorization and identity to existing user and deletes current user" do
        expect { subject.call }.to broadcast(:ok, email)
        expect(Decidim::User.count).to eq(1)
        expect(Decidim::User.last.id).to eq(existing_user.id)
        existing_user = Decidim::User.last
        expect(existing_user.confirmed_at).to be_between(1.minute.ago, Time.current)
        expect(Decidim::Identity.last.user).to eq(existing_user)
        expect(Decidim::Authorization.last.user).to eq(existing_user)
      end
    end

    context "when the form is valid" do
      it "broadcasts ok" do
        expect { subject.call }.to broadcast(:ok, email)
      end
    end

    context "when form is invalid" do
      let(:invalid) { true }

      it "broadcasts invalid" do
        expect { subject.call }.to broadcast(:invalid)
      end
    end
  end
end
