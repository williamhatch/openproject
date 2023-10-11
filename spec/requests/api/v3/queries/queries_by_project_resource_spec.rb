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

RSpec.describe 'API v3 Query resource' do
  include Rack::Test::Methods
  include API::V3::Utilities::PathHelper

  let(:project) { create(:project, identifier: 'test_project', public: false) }
  let(:current_user) do
    create(:user, member_in_project: project, member_through_role: role)
  end
  let(:role) { create(:project_role, permissions:) }
  let(:permissions) { [:view_work_packages] }

  before do
    allow(User).to receive(:current).and_return current_user
  end

  describe '#get projects/:project_id/queries/default' do
    let(:base_path) { api_v3_paths.query_project_default(project.id) }

    it_behaves_like 'GET individual query' do
      context 'lacking permissions' do
        let(:permissions) { [] }

        it_behaves_like 'unauthorized access'
      end
    end
  end
end
