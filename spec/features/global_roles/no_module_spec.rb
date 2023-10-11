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
require_relative 'mock_global_permissions'

RSpec.describe 'Global role: No module',
               js: true,
               with_cuprite: true do
  let(:admin) { create(:admin) }
  let(:project) { create(:project) }
  let!(:role) { create(:project_role) }

  # Scenario:
  # Given there is the global permission "glob_test" of the module "global"
  include_context 'with mocked global permissions', [['global_perm1', { project_module: :global }]]

  before do
    login_as admin
  end

  it 'Global Rights Modules do not exist as Project -> Settings -> Modules' do
    # And there is 1 project with the following:
    # | name       | test |
    # | identifier | test |
    #   And I am already admin
    # When I go to the modules tab of the settings page for the project "test"
    #                                                     Then I should not see "Global"
    visit project_settings_modules_path(project)

    expect(page).to have_text 'Activity'
    expect(page).not_to have_text 'Foo'
  end
end
