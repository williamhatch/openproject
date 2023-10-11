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

require 'rack/test'

RSpec.shared_examples_for 'available principals' do |principals|
  include API::V3::Utilities::PathHelper

  current_user do
    create(:user,
           member_in_project: project,
           member_through_role: role)
  end
  let(:other_user) do
    create(:user,
           member_in_project: project,
           member_through_role: assignable_role)
  end
  let(:role) { create(:project_role, permissions:) }
  let(:assignable_role) { create(:project_role, permissions: assignable_permissions) }
  let(:project) { create(:project) }
  let(:group) do
    create(:group,
           member_in_project: project,
           member_through_role: assignable_role)
  end
  let(:placeholder_user) do
    create(:placeholder_user,
           member_in_project: project,
           member_through_role: assignable_role)
  end
  let(:permissions) { [:view_work_packages] }
  let(:assignable_permissions) { [:work_package_assigned] }

  shared_context "request available #{principals}" do
    before { get href }
  end

  describe 'response' do
    shared_examples_for "returns available #{principals}" do |total, count, klass|
      include_context "request available #{principals}"

      it_behaves_like 'API V3 collection response', total, count, klass
    end

    describe 'users' do
      let(:permissions) { %i[view_work_packages work_package_assigned] }

      context 'for a single user' do
        # The current user

        it_behaves_like "returns available #{principals}", 1, 1, 'User'
      end

      context 'for multiple users' do
        before do
          other_user
          # and the current user
        end

        it_behaves_like "returns available #{principals}", 2, 2, 'User'
      end

      context 'if the user lacks the assignable permission' do
        let(:permissions) { %i[view_work_packages] }

        it_behaves_like "returns available #{principals}", 0, 0, 'User'
      end
    end

    describe 'groups' do
      let!(:users) { [group] }

      it_behaves_like "returns available #{principals}", 1, 1, 'Group'
    end

    describe 'placeholder users' do
      let!(:users) { [placeholder_user] }

      it_behaves_like "returns available #{principals}", 1, 1, 'PlaceholderUser'
    end
  end

  describe 'if not allowed' do
    include Rack::Test::Methods
    let(:permissions) { [] }

    before { get href }

    it_behaves_like 'unauthorized access'
  end
end
