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

RSpec.describe 'Global role: Global Create project',
               js: true,
               with_cuprite: true do
  shared_let(:admin) { create(:admin) }
  shared_let(:user) { create(:user) }
  shared_let(:project) { create(:project) }

  describe 'Create project is not a member permission' do
    # Given there is a role "Member"
    let!(:role) { create(:project_role, name: 'Member') }

    # And I am already admin
    current_user { admin }

    # When I go to the edit page of the role "Member"
    # Then I should not see "Create project"
    it 'does not show the global permission' do
      visit edit_role_path(role)
      expect(page).to have_selector('.form--label-with-check-box', text: 'Edit project')
      expect(page).not_to have_selector('.form--label-with-check-box', text: 'Create project')
    end
  end

  describe 'Create project is a global permission' do
    # Given there is a global role "Global"
    let!(:role) { create(:global_role, name: 'Global') }

    # And I am already admin
    current_user { admin }

    # When I go to the edit page of the role "Global"
    # Then I should see "Create project"

    it 'does show the global permission' do
      visit edit_role_path(role)
      expect(page).not_to have_selector('.form--label-with-check-box', text: 'Edit project')
      expect(page).to have_selector('.form--label-with-check-box', text: 'Create project')
    end
  end

  describe 'Create project displayed to user' do
    let!(:global_role) { create(:global_role, name: 'Global', permissions: %i[add_project]) }
    let!(:member_role) { create(:project_role, name: 'Member', permissions: %i[view_project]) }

    let!(:global_member) do
      create(:global_member,
             principal: user,
             roles: [global_role])
    end

    let(:name_field) { FormFields::InputFormField.new :name }

    current_user { user }

    it 'does show the global permission' do
      visit projects_path
      expect(page).to have_selector('.button.-alt-highlight', text: 'Project')

      # Can add new project
      visit new_project_path

      name_field.set_value 'New project name'

      find('button:not([disabled])', text: 'Save').click

      expect(page).to have_current_path '/projects/new-project-name/'
    end
  end

  describe 'Create project not displayed to user without global role' do
    # Given there is 1 User with:
    # | Login | bob |
    # | Firstname | Bob |
    # | Lastname | Bobbit |
    #   When I am already logged in as "bob"

    current_user { user }

    it 'does show the global permission' do
      # And I go to the overall projects page
      visit projects_path
      # Then I should not see "Project" within ".toolbar-items"
      expect(page).not_to have_selector('.button.-alt-highlight', text: 'Project')
    end
  end
end
