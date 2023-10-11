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
require 'work_package'

RSpec.describe Users::MembershipsController do
  shared_let(:admin) { create(:admin) }

  let(:user) { create(:user) }
  let(:anonymous) { create(:anonymous) }

  describe 'update memberships' do
    let(:project) { create(:project) }
    let(:role) { create(:project_role) }

    it 'works' do
      # i.e. it should successfully add a user to a project's members
      as_logged_in_user admin do
        post :create,
             params: {
               user_id: user.id,
               membership: {
                 project_id: project.id,
                 role_ids: [role.id]
               }
             }
      end

      expect(response).to redirect_to(controller: '/users', action: 'edit', id: user.id, tab: 'memberships')

      is_member = user.reload.memberships.any? do |m|
        m.project_id == project.id && m.role_ids.include?(role.id)
      end
      expect(is_member).to be(true)
    end
  end
end
