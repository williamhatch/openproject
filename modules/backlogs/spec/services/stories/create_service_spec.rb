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

RSpec.describe Stories::CreateService, type: :model do
  let(:priority) { create(:priority) }
  let(:project) do
    project = create(:project, types: [type_feature])

    create(:member,
           principal: user,
           project:,
           roles: [role])
    project
  end
  let(:role) { create(:project_role, permissions:) }
  let(:permissions) { %i(add_work_packages manage_subtasks assign_versions) }
  let(:status) { create(:status) }
  let(:type_feature) { create(:type_feature) }

  let(:user) do
    create(:user)
  end

  let(:instance) do
    Stories::CreateService
      .new(user:)
  end

  let(:attributes) do
    {
      project:,
      status:,
      type: type_feature,
      priority:,
      parent_id: story.id,
      remaining_hours:,
      subject: 'some subject'
    }
  end

  let(:version) { create(:version, project:) }

  let(:story) do
    project.enabled_module_names += ['backlogs']

    create(:story,
           version:,
           project:,
           status:,
           type: type_feature,
           priority:)
  end

  before do
    allow(User).to receive(:current).and_return(user)
  end

  subject { instance.call(attributes:) }

  describe "remaining_hours" do
    before do
      subject
    end

    context 'with the story having remaining_hours' do
      let(:remaining_hours) { 15.0 }

      it 'does update the parents remaining hours' do
        expect(story.reload.derived_remaining_hours).to eq(15)
      end
    end

    context 'with the subtask not having remaining_hours' do
      let(:remaining_hours) { nil }

      it 'does not note remaining hours to be changed' do
        expect(story.reload.remaining_hours).to be_nil
      end
    end
  end
end
