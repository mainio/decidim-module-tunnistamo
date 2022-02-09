# frozen_string_literal: true

require "spec_helper"

module Decidim::Tunnistamo
  describe SendConfirmationEmail do
    subject { described_class.new(form, user) }

    let(:organization) { create(:organization) }
    let(:user) { create(:user, organization: organization) }

    let(:form) { double(email: email, invalid?: false) }
    let(:email) { Faker::Internet.email }

    context "when user doesnt have confirmation token" do
      before do
        user.update!(confirmation_token: nil)
      end

      it "creates new token" do
        expect(user.confirmation_token).to be_nil
        subject.call
        expect(user.confirmation_token).not_to be_nil
      end
    end

    context "when the form is valid" do
      it "broadcasts ok" do
        expect { subject.call }.to broadcast(:ok)
      end

      it "updates user" do
        subject.call
        expect(user.tunnistamo_email_code).not_to be_empty
        expect(user.unconfirmed_email).to eq(email)
        expect(user.tunnistamo_failed_confirmation_attempts).to eq(0)
      end
    end

    context "when email is missing" do
      let(:email) {}

      it "broadcasts invalid" do
        expect { subject.call }.to broadcast(:invalid)
        expect(user.tunnistamo_email_code).to be_nil
        expect(user.unconfirmed_email).to be_nil
      end
    end
  end
end
