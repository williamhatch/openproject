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

RSpec.describe Members::Scopes::NotLocked do
  let(:project) { create(:project) }
  let(:role) { create(:project_role) }

  let!(:invited_user_member) do
    create(:member,
           project:,
           roles: [role],
           principal: create(:user, status: Principal.statuses[:invited]))
  end
  let!(:registered_user_member) do
    create(:member,
           project:,
           roles: [role],
           principal: create(:user, status: Principal.statuses[:registered]))
  end
  let!(:locked_user_member) do
    create(:member,
           project:,
           roles: [role],
           principal: create(:user, status: Principal.statuses[:locked]))
  end
  let!(:active_user_member) do
    create(:member,
           project:,
           roles: [role],
           principal: create(:user, status: Principal.statuses[:active]))
  end
  let!(:group_member) do
    create(:member,
           project:,
           roles: [role],
           principal: create(:group))
  end

  describe '.fetch' do
    subject { Member.not_locked }

    it 'returns only actual users and groups' do
      expect(subject)
        .to match_array [active_user_member,
                         invited_user_member,
                         registered_user_member,
                         group_member]
    end
  end
end
