# frozen_string_literal: true

module Decidim
  module Tunnistamo
    # This is a customized form builder in order to create Foundation group
    # fields that do not limit the "prefix" or "suffix" length through columns.
    # This allows creating `input-group` elements according to the Foundation
    # docs with the automated field errors shown properly for the field.
    class FormBuilder < Decidim::FormBuilder
      # Creates the following kind of markup with the `:prefix` option for a
      # required field:
      #
      #  <%= form.group_text_field(:attribute, prefix: "Prefix") %>
      #  =>
      #    <label for="object_attribute">
      #      Attribute
      #      <span title="Required field" data-tooltip="true" data-disable-hover="false" data-keep-on-hover="true" aria-haspopup="true" class="label-required">
      #        <span aria-hidden="true">*</span>
      #        <span class="show-for-sr">Required field</span>
      #      </span>
      #    </label>
      #    <div class="input-group">
      #      <span class="input-group-label">Prefix</span>
      #      <input type="text" name="object[attribute]" id="object_attribute">
      #    </div>
      #    <span class="form-error" data-form-error-for="object_attribute">There's an error in this field.</span>
      #
      # Creates the following kind of markup with the `:suffix` option for a
      # required field:
      #
      #  <%= form.group_text_field(:attribute, suffix: "Suffix") %>
      #  =>
      #    <label for="object_attribute">
      #      Attribute
      #      <span title="Required field" data-tooltip="true" data-disable-hover="false" data-keep-on-hover="true" aria-haspopup="true" class="label-required">
      #        <span aria-hidden="true">*</span>
      #        <span class="show-for-sr">Required field</span>
      #      </span>
      #    </label>
      #    <div class="input-group">
      #      <input type="text" name="object[attribute]" id="object_attribute">
      #      <span class="input-group-label">Suffix</span>
      #    </div>
      #    <span class="form-error" data-form-error-for="object_attribute">There's an error in this field.</span>
      #
      def group_text_field(attribute, options = {})
        group_field(attribute, options) do |field_options|
          ActionView::Helpers::Tags::TextField.new(@object_name, attribute, self, field_options).render
        end
      end

      private

      # Wrapper for any group fields. See above example for the text group
      # field. The group markup is the same but the fields can differ for
      # different purposes.
      def group_field(attribute, options)
        field_options = extract_validations(attribute, options.dup)
        cls = "input-group-field #{options[:class]}".strip
        cls = "#{cls} is-invalid-input" if error?(attribute)
        field_options[:class] = cls

        label = options.delete(:label)
        label_options = options.delete(:label_options)
        label_html = custom_label(attribute, label, label_options) {}
        group_html = content_tag(:div, class: "input-group") do
          inner = []
          inner << content_tag(:span, options[:prefix], class: "input-group-label") if options[:prefix]
          inner << yield(field_options)
          inner << content_tag(:span, options[:suffix], class: "input-group-label") if options[:suffix]

          safe_join(inner)
        end
        errors_html = ""
        if attribute_required?(attribute)
          error_text = I18n.t("decidim.forms.errors.error", count: 1)
          errors_html = content_tag(:span, error_text, class: "form-error", data: { form_error_for: "#{@object_name}_#{attribute}" })
        end

        safe_join([label_html, group_html, errors_html, error_and_help_text(attribute)])
      end
    end
  end
end
