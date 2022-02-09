# frozen_string_literal: true

require "spec_helper"

module Decidim::Tunnistamo
  describe ConfirmToken do
    subject { described_class.new(form) }

    let(:organization) { create(:organization) }
    let(:user) do
      create(
        :user,
        organization: organization,
        tunnistamo_email_sent_to: email,
        tunnistamo_email_code_sent_at: Time.current,
        tunnistamo_email_code: "123456",
        confirmation_token: confirmation_token
      )
    end
    let(:form) do
      double(
        current_organization: organization,
        current_user: user,
        email: email,
        invalid?: invalid,
        user: user,
        confirmation_token: confirmation_token
      )
    end
    let(:email) { Faker::Internet.unique.email }
    let(:invalid) { false }
    let(:confirmation_token) { ::Faker::Internet.password }

    before do
      allow(subject).to receive(:bypass_sign_in).and_return(true)
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
