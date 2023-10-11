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
require 'rack/test'

RSpec.describe 'API v3 Principals resource' do
  include Rack::Test::Methods
  include API::V3::Utilities::PathHelper

  describe '#GET /api/v3/principals' do
    subject(:response) { last_response }

    let(:path) do
      api_v3_paths.path_for :principals, filters: filter, sort_by: order, select:
    end
    let(:order) { { name: :desc } }
    let(:filter) { nil }
    let(:select) { nil }
    let(:project) { create(:project) }
    let(:other_project) { create(:project) }
    let(:non_member_project) { create(:project) }
    let(:role) { create(:project_role, permissions:) }
    let(:permissions) { [] }
    let(:user) do
      user = create(:user,
                    member_in_project: project,
                    member_through_role: role,
                    lastname: 'Aaaa',
                    mail: 'aaaa@example.com')

      create(:member,
             project: other_project,
             principal: user,
             roles: [role])

      user
    end
    let!(:other_user) do
      create(:user,
             member_in_project: other_project,
             member_through_role: role,
             lastname: 'Bbbb')
    end
    let!(:user_in_non_member_project) do
      create(:user,
             member_in_project: non_member_project,
             member_through_role: role,
             lastname: 'Cccc')
    end
    let!(:group) do
      create(:group,
             member_in_project: project,
             member_through_role: role,
             lastname: 'Gggg')
    end
    let!(:placeholder_user) do
      create(:placeholder_user,
             member_in_project: project,
             member_through_role: role,
             name: 'Pppp')
    end

    current_user { user }

    before do
      get path
    end

    it 'succeeds' do
      expect(response.status)
        .to eq(200)
    end

    it_behaves_like 'API V3 collection response', 4, 4 do
      let(:elements) { [placeholder_user, group, other_user, user] }
    end

    context 'with a filter for project the user is member in' do
      let(:filter) do
        [{ member: { operator: '=', values: [project.id.to_s] } }]
      end

      it_behaves_like 'API V3 collection response', 3, 3
    end

    context 'with a filter for type "User"' do
      let(:filter) do
        [{ type: { operator: '=', values: ['User'] } }]
      end

      it_behaves_like 'API V3 collection response', 2, 2, nil
    end

    context 'with a filter for type "Group"' do
      let(:filter) do
        [{ type: { operator: '=', values: ['Group'] } }]
      end

      it_behaves_like 'API V3 collection response', 1, 1, 'Group'
    end

    context 'with a filter for type "PlaceholderUser"' do
      let(:filter) do
        [{ type: { operator: '=', values: ['PlaceholderUser'] } }]
      end

      it_behaves_like 'API V3 collection response', 1, 1, 'PlaceholderUser'
    end

    context 'with a without a project membership' do
      let(:user) { create(:user) }

      # The user herself
      it_behaves_like 'API V3 collection response', 1, 1, 'User'
    end

    context 'with a filter for any name attribute' do
      let(:filter) do
        [{ any_name_attribute: { operator: '~', values: ['aaaa@example.com'] } }]
      end

      it_behaves_like 'API V3 collection response', 1, 1, 'User'
    end

    context 'with a filter for id' do
      let(:filter) do
        [{ id: { operator: '=', values: [user.id.to_s] } }]
      end

      it_behaves_like 'API V3 collection response', 1, 1, 'User' do
        let(:elements) { [user] }
      end
    end

    context 'with a filter for id with the `me` value' do
      let(:filter) do
        [{ id: { operator: '=', values: ['me'] } }]
      end

      it_behaves_like 'API V3 collection response', 1, 1, 'User' do
        let(:elements) { [current_user] }
      end
    end

    context 'with the permission to `manage_members`' do
      let(:permissions) { [:manage_members] }

      it_behaves_like 'API V3 collection response', 5, 5 do
        let(:elements) { [placeholder_user, group, user_in_non_member_project, other_user, user] }
      end
    end

    context 'with the permission to `manage_user`' do
      let(:permissions) { [:manage_user] }

      it_behaves_like 'API V3 collection response', 5, 5 do
        let(:elements) { [placeholder_user, group, user_in_non_member_project, other_user, user] }
      end
    end

    context 'with the permission to `share_work_packages`' do
      let(:permissions) { [:share_work_packages] }

      it_behaves_like 'API V3 collection response', 5, 5 do
        let(:elements) { [placeholder_user, group, user_in_non_member_project, other_user, user] }
      end
    end

    context 'when signaling' do
      let(:select) { 'total,count,elements/*' }

      let(:expected) do
        {
          total: 4,
          count: 4,
          _embedded: {
            elements: [
              {
                _type: 'PlaceholderUser',
                id: placeholder_user.id,
                name: placeholder_user.name,
                _links: {
                  self: {
                    href: api_v3_paths.placeholder_user(placeholder_user.id),
                    title: placeholder_user.name
                  }
                }
              },
              {
                _type: 'Group',
                id: group.id,
                name: group.name,
                _links: {
                  self: {
                    href: api_v3_paths.group(group.id),
                    title: group.name
                  }
                }
              },
              {
                _type: "User",
                id: other_user.id,
                name: other_user.name,
                _links: {
                  self: {
                    href: api_v3_paths.user(other_user.id),
                    title: other_user.name
                  }
                }
              },
              {
                _type: "User",
                id: user.id,
                name: user.name,
                firstname: user.firstname,
                lastname: user.lastname,
                _links: {
                  self: {
                    href: api_v3_paths.user(user.id),
                    title: user.name
                  }
                }
              }
            ]
          }
        }
      end

      it 'is the reduced set of properties of the embedded elements' do
        expect(last_response.body)
          .to be_json_eql(expected.to_json)
      end
    end
  end
end
