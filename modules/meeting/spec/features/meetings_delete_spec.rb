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

RSpec.describe 'Meetings deletion' do
  let(:project) { create(:project, enabled_module_names: %w[meetings]) }
  let(:user) do
    create(:user,
           member_with_permissions: { project => permissions })
  end
  let(:other_user) do
    create(:user,
           member_with_permissions: { project => permissions })
  end

  let!(:meeting) { create(:meeting, project:, title: 'Own awesome meeting!', author: user) }
  let!(:other_meeting) { create(:meeting, project:, title: 'Other awesome meeting!', author: other_user) }

  let(:index_path) { project_meetings_path(project) }

  before do
    login_as(user)
  end

  context 'with permission to delete meetings', :js do
    let(:permissions) { %i[view_meetings delete_meetings] }

    it "can delete own and other's meetings" do
      visit index_path

      click_link meeting.title
      accept_confirm do
        click_link "Delete"
      end

      expect(page)
        .to have_current_path index_path

      click_link other_meeting.title
      accept_confirm do
        click_link "Delete"
      end

      expect(page)
        .to have_content(I18n.t('.no_results_title_text', cascade: true))

      expect(page)
        .to have_current_path index_path
    end
  end

  context 'without permission to delete meetings' do
    let(:permissions) { %i[view_meetings] }

    it "cannot delete own and other's meetings" do
      visit index_path

      click_link meeting.title
      expect(page)
        .not_to have_link 'Delete'

      visit index_path

      click_link other_meeting.title
      expect(page)
        .not_to have_link 'Delete'
    end
  end
end
