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

RSpec.describe PlaceholderUsers::DeleteService, type: :model do
  let(:placeholder_user) { build_stubbed(:placeholder_user) }
  let(:project) { build_stubbed(:project) }

  let(:instance) { described_class.new(model: placeholder_user, user: actor) }

  subject { instance.call }

  shared_examples 'deletes the user' do
    it do
      expect(placeholder_user).to receive(:locked!)
      expect(Principals::DeleteJob).to receive(:perform_later).with(placeholder_user)
      expect(subject).to be_success
    end
  end

  shared_examples 'does not delete the user' do
    it do
      expect(placeholder_user).not_to receive(:locked!)
      expect(Principals::DeleteJob).not_to receive(:perform_later)
      expect(subject).not_to be_success
    end
  end

  context 'with admin user' do
    let(:actor) { build_stubbed(:admin) }

    it_behaves_like 'deletes the user'
  end

  context 'with global user' do
    let(:actor) do
      build_stubbed(:user).tap do |u|
        allow(u).to receive(:allowed_globally?) do |permission|
          [:manage_placeholder_user].include?(permission)
        end
      end
    end

    it_behaves_like 'deletes the user'
  end

  context 'with unprivileged system user' do
    let(:actor) { User.system }

    before do
      allow(actor).to receive(:admin?).and_return false
    end

    it_behaves_like 'does not delete the user'
  end

  context 'with privileged system user' do
    let(:actor) { User.system }

    it_behaves_like 'deletes the user' do
      around do |example|
        actor.run_given { example.run }
      end
    end
  end
end
