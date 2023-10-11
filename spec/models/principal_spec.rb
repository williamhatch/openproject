# frozen_string_literal: true

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

RSpec.describe Principal do
  let(:user) { build(:user) }
  let(:group) { build(:group) }

  def self.should_return_groups_and_users_if_active(method, *)
    it 'returns a user' do
      user.save!

      expect(described_class.send(method, *).where(id: user.id)).to eq([user])
    end

    it 'returns a group' do
      group.save!

      expect(described_class.send(method, *).where(id: group.id)).to eq([group])
    end

    it 'does not return the anonymous user' do
      User.anonymous

      expect(described_class.send(method, *).where(id: user.id)).to eq([])
    end

    it 'does not return an inactive user' do
      user.status = User.statuses[:locked]

      user.save!

      expect(described_class.send(method, *).where(id: user.id).to_a).to eq([])
    end
  end

  describe 'associations' do
    subject { described_class.new }

    it { is_expected.to have_many(:work_package_shares).conditions(entity_type: WorkPackage.name) }
  end

  describe 'active' do
    should_return_groups_and_users_if_active(:active)

    it 'does not return a registered user' do
      user.status = User.statuses[:registered]

      user.save!

      expect(described_class.active.where(id: user.id)).to eq([])
    end
  end

  describe 'not_locked' do
    should_return_groups_and_users_if_active(:not_locked)

    it 'returns a registered user' do
      user.status = User.statuses[:registered]

      user.save!

      expect(described_class.not_locked.where(id: user.id)).to eq([user])
    end
  end
end
