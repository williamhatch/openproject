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

RSpec.describe WorkPackages::CreateService, 'integration', type: :model do
  let(:user) do
    create(:user,
           member_in_project: project,
           member_through_role: role)
  end
  let(:role) do
    create(:project_role,
           permissions:)
  end

  let(:permissions) do
    %i(view_work_packages add_work_packages manage_subtasks)
  end

  let(:type) do
    create(:type,
           custom_fields: [custom_field])
  end
  let(:default_type) do
    create(:type_standard)
  end
  let(:project) { create(:project, types: [type, default_type]) }
  let(:parent) do
    create(:work_package,
           project:,
           type:)
  end
  let(:instance) { described_class.new(user:) }
  let(:custom_field) { create(:work_package_custom_field) }
  let(:other_status) { create(:status) }
  let(:default_status) { create(:default_status) }
  let(:priority) { create(:priority) }
  let(:default_priority) { create(:default_priority) }
  let(:attributes) { {} }
  let(:new_work_package) do
    service_result
      .result
  end
  let(:service_result) do
    instance
      .call(**attributes)
  end

  before do
    other_status
    default_status
    priority
    default_priority
    type
    default_type
    login_as(user)
  end

  describe '#call' do
    let(:attributes) do
      { subject: 'blubs',
        project:,
        done_ratio: 50,
        parent:,
        start_date: Date.today,
        due_date: Date.today + 3.days }
    end

    it 'creates the work_package with the provided attributes and sets the user as a watcher' do
      # successful
      expect(service_result)
        .to be_success

      # attributes set as desired
      attributes.each do |key, value|
        expect(new_work_package.send(key))
          .to eql value
      end

      # service user as author
      expect(new_work_package.author)
        .to eql(user)

      # assign the default status
      expect(new_work_package.status)
        .to eql(default_status)

      # assign the first type in the project (not related to is_default)
      expect(new_work_package.type)
        .to eql(type)

      # assign the default priority
      expect(new_work_package.priority)
        .to eql(default_priority)

      # parent updated
      parent.reload
      expect(parent.done_ratio)
        .to eql attributes[:done_ratio]
      expect(parent.start_date)
        .to eql attributes[:start_date]
      expect(parent.due_date)
        .to eql attributes[:due_date]

      # adds the user (author) as watcher
      expect(new_work_package.watcher_users)
        .to match_array([user])
    end

    describe 'setting the attachments' do
      let!(:other_users_attachment) do
        create(:attachment, container: nil, author: create(:user))
      end
      let!(:users_attachment) do
        create(:attachment, container: nil, author: user)
      end

      it 'reports on invalid attachments and sets the new if everything is valid' do
        result = instance.call(**attributes.merge(attachment_ids: [other_users_attachment.id]))

        expect(result)
          .to be_failure

        expect(result.errors.symbols_for(:attachments))
          .to match_array [:does_not_exist]

        # The parent work package
        expect(WorkPackage.count)
          .to be 1

        expect(other_users_attachment.reload.container)
          .to be_nil

        result = instance.call(**attributes.merge(attachment_ids: [users_attachment.id]))

        expect(result)
          .to be_success

        expect(result.result.attachments)
          .to match_array [users_attachment]

        expect(users_attachment.reload.container)
          .to eql result.result
      end
    end
  end
end
