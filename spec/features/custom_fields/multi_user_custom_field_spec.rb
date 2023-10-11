require "spec_helper"
require "support/pages/work_packages/abstract_work_package"

RSpec.describe "multi select custom values",
               js: true,
               with_cuprite: true do
  shared_let(:admin) { create(:admin) }
  let(:current_user) { admin }
  let(:wp_page) { Pages::FullWorkPackage.new work_package }
  let(:cf_edit_field) do
    field = wp_page.edit_field custom_field.attribute_name(:camel_case)
    field.field_type = 'create-autocompleter'
    field
  end

  shared_let(:type) { create(:type) }
  shared_let(:project) { create(:project, types: [type]) }
  shared_let(:role) { create(:project_role) }

  shared_let(:custom_field) do
    create(
      :user_wp_custom_field,
      name: "Reviewer",
      multi_value: true,
      types: [type],
      projects: [project]
    )
  end

  before do
    login_as current_user
    wp_page.visit!
    wait_for_reload
  end

  describe 'with mixed users, group, and placeholders' do
    let(:work_package) { create(:work_package, project:, type:) }

    let!(:user) do
      create(:user,
             firstname: 'Da Real',
             lastname: 'User',
             member_in_project: project,
             member_through_role: role)
    end

    let!(:group) do
      create(:group,
             name: 'groupfoo',
             member_in_project: project,
             member_through_role: role)
    end

    let!(:placeholder) do
      create(:placeholder_user,
             name: 'PLACEHOLDER',
             member_in_project: project,
             member_through_role: role)
    end

    it "is shown and allowed to be updated" do
      expect(page).to have_text custom_field.name

      cf_edit_field.activate!
      cf_edit_field.set_value "Da Real"
      cf_edit_field.set_value "groupfoo"
      cf_edit_field.set_value "PLACEHOLDER"

      cf_edit_field.submit_by_dashboard

      expect(page).to have_text custom_field.name
      expect(page).to have_text "Da Real"
      expect(page).to have_text "groupfoo"
      expect(page).to have_text "PLACEHOLDER"

      wp_page.expect_and_dismiss_toaster(message: "Successful update.")

      work_package.reload
      cvs = work_package
          .custom_value_for(custom_field)
          .map(&:typed_value)

      expect(cvs).to contain_exactly(group, user, placeholder)

      cf_edit_field.activate!
      cf_edit_field.unset_value "Da Real", multi: true
      cf_edit_field.submit_by_dashboard

      wp_page.expect_and_dismiss_toaster(message: "Successful update.")

      expect(page).to have_text "groupfoo"
      expect(page).to have_text "PLACEHOLDER"
      expect(page).not_to have_text "Da Real"

      work_package.reload
      cvs = work_package
          .custom_value_for(custom_field)
          .map(&:typed_value)

      expect(cvs).to contain_exactly(group, placeholder)
    end
  end

  describe 'with all users' do
    let!(:user1) do
      create(:user,
             firstname: 'Billy',
             lastname: 'Nobbler',
             member_in_project: project,
             member_through_role: role)
    end

    let!(:user2) do
      create(:user,
             firstname: 'Cooper',
             lastname: 'Quatermaine',
             member_in_project: project,
             member_through_role: role)
    end

    let!(:user3) do
      create(:user,
             firstname: 'Anton',
             lastname: 'Lupin',
             status: User.statuses[:invited],
             member_in_project: project,
             member_through_role: role)
    end

    context "with existing custom values" do
      let(:work_package) do
        wp = build(:work_package, project:, type:)

        wp.custom_field_values = {
          custom_field.id => [user1.id.to_s, user3.id.to_s]
        }

        wp.save
        wp
      end

      it "is shown and allowed to be updated" do
        expect(page).to have_text custom_field.name
        expect(page).to have_text "Billy Nobbler"
        expect(page).to have_text "Anton Lupin"

        page.find(".inline-edit--display-field", text: "Billy Nobbler").click

        wait_for_reload

        cf_edit_field.unset_value "Anton Lupin", multi: true
        cf_edit_field.set_value "Cooper Quatermaine"

        click_on "Reviewer: Save"
        wp_page.expect_and_dismiss_toaster(message: "Successful update.")
        expect(page).to have_selector('.custom-option', count: 2)

        expect(page).to have_text custom_field.name
        expect(page).to have_text "Billy Nobbler"
        expect(page).not_to have_text "Anton Lupin"
        expect(page).to have_text "Cooper Quatermaine"
      end
    end
  end
end
