#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) 2012-2023 the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++

require 'spec_helper'

RSpec.describe 'Wysiwyg work package mentions',
               :js,
               :with_cuprite do
  let!(:user) { create(:admin, firstname: 'MeMyself', lastname: 'AndI', member_in_project: project) }
  let!(:user2) { create(:user, firstname: 'Foo', lastname: 'Bar', member_in_project: project) }
  let!(:group) { create(:group, firstname: 'Foogroup', lastname: 'Foogroup') }
  let!(:group_role) { create(:project_role) }
  let!(:group_member) do
    create(:member,
           principal: group,
           project:,
           roles: [group_role])
  end
  let(:project) { create(:project, enabled_module_names: %w[work_package_tracking]) }
  let!(:work_package) do
    User.execute_as user do
      create(:work_package, subject: 'Foobar', project:)
    end
  end

  let(:wp_page) { Pages::FullWorkPackage.new work_package, project }
  let(:editor) { Components::WysiwygEditor.new }

  let(:selector) { '.work-packages--activity--add-comment' }
  let(:comment_field) do
    TextEditorField.new wp_page,
                        'comment',
                        selector:
  end

  before do
    login_as(user)
    wp_page.visit!
    wait_for_reload
    expect_angular_frontend_initialized
  end

  it 'can autocomplete users, groups and emojis' do
    # Mentioning a user works
    comment_field.activate!

    comment_field.clear with_backspace: true
    comment_field.input_element.send_keys("@Foo")
    expect(page).to have_selector('.mention-list-item', text: user2.name)
    expect(page).to have_selector('.mention-list-item', text: group.name)

    page.find('.mention-list-item', text: user2.name).click

    expect(page)
      .to have_selector('a.mention', text: '@Foo Bar')

    comment_field.submit_by_click if comment_field.active?

    wp_page.expect_and_dismiss_toaster message: "The comment was successfully added."

    expect(page)
      .to have_selector('a.user-mention', text: 'Foo Bar')

    # Mentioning myself works
    comment_field.activate!

    comment_field.clear with_backspace: true
    comment_field.input_element.send_keys("@MeMyself")
    expect(page).to have_selector('.mention-list-item', text: user.name)

    page.find('.mention-list-item', text: user.name).click

    expect(page)
      .to have_selector('a.mention', text: '@MeMyself AndI')

    comment_field.submit_by_click if comment_field.active?

    wp_page.expect_and_dismiss_toaster message: "The comment was successfully added."

    expect(page)
      .to have_selector('a.user-mention', text: 'MeMyself AndI')

    # Mentioning a group works
    comment_field.activate!
    comment_field.clear with_backspace: true
    comment_field.input_element.send_keys(" @Foo")
    expect(page).to have_selector('.mention-list-item', text: user2.name)
    expect(page).to have_selector('.mention-list-item', text: group.name)

    page.find('.mention-list-item', text: group.name).click

    expect(page)
      .to have_selector('a.mention', text: '@Foogroup')

    comment_field.submit_by_click if comment_field.active?

    wp_page.expect_and_dismiss_toaster message: "The comment was successfully added."

    expect(page)
      .to have_selector('a.user-mention', text: 'Foogroup')

    # The mention is still displayed as such when reentering the comment field
    find('#activity-1 .op-user-activity')
      .hover

    within('#activity-1') do
      click_button("Edit this comment")
    end

    expect(page)
      .to have_selector('a.mention', text: '@Foo Bar')

    # Mentioning an emoji works
    comment_field.activate!
    comment_field.clear with_backspace: true
    comment_field.input_element.send_keys(":thumbs")
    expect(page).to have_selector('.mention-list-item', text: '👍 thumbs_up')
    expect(page).to have_selector('.mention-list-item', text: '👎 thumbs_down')

    page.find('.mention-list-item', text: '👍 thumbs_up').click

    expect(page).to have_selector('span', text: '👍')
  end
end
