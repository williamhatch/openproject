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

# TODO: Fix tests here

RSpec.describe Authorization::UserAllowedService do
  let(:user) { build_stubbed(:user) }
  let(:instance) { described_class.new(user) }
  let(:action) { :an_action }
  let(:action_hash) { { controller: '/controller', action: 'action' } }
  let(:project) { build_stubbed(:project) }
  let(:other_project) { build_stubbed(:project) }
  let(:role) { build_stubbed(:project_role) }
  let(:user_roles_in_project) do
    array = [role]
    allow(array)
      .to receive(:eager_load)
      .and_return(array)

    array
  end
  let(:role_grants_action) { true }
  let(:project_allows_to) { true }

  subject { instance.call(action, context) }

  describe '#initialize' do
    it 'has the user' do
      expect(instance.user).to eql user
    end
  end

  shared_examples_for 'allowed to checked' do
    before do
      Array(context).each do |project|
        project.active = true

        allow(project)
          .to receive(:allows_to?)
          .with(action)
          .and_return(project_allows_to)

        allow(Authorization)
          .to receive(:roles)
          .with(user, project)
          .and_return(user_roles_in_project)
      end

      allow(role)
        .to receive(:allowed_to?)
        .with(action)
        .and_return(role_grants_action)
    end

    context 'with the user having a granting role' do
      it 'is true' do
        expect(subject).to be_truthy
      end

      it 'does not call the db twice for a project' do
        Array(context).each do |project|
          allow(Authorization)
            .to receive(:roles)
            .with(user, project)
            .and_return(user_roles_in_project)
        end

        subject
        subject

        Array(context).each do |project|
          expect(Authorization)
            .to have_received(:roles)
            .once
            .with(user, project)
        end
      end

      context 'but the user not being active' do
        before do
          user.lock
        end

        it 'returns false', :aggregate_failures do
          expect(instance.call(action, nil, global: true)).not_to be_truthy
        end
      end
    end

    context 'with the user having a nongranting role' do
      let(:role_grants_action) { false }

      it 'is false' do
        expect(subject).to be_falsey
      end
    end

    context 'with the user being admin
             with the user not having a granting role' do
      let(:user_roles_in_project) { [] }

      before do
        user.admin = true
      end

      it 'is true' do
        expect(subject).to be_truthy
      end
    end

    context 'with the project not being active' do
      before do
        Array(context).each do |project|
          project.active = false
          project.clear_changes_information
        end
      end

      it 'is false' do
        expect(subject).to be_falsey
      end

      it 'is false even if the user is admin' do
        user.admin = true

        expect(subject).to be_falsey
      end
    end

    context 'with the project being archived' do
      before do
        Array(context).each do |project|
          project.active = false
        end
      end

      it 'is true' do
        expect(subject).to be_truthy
      end
    end

    context 'with the project not having the action enabled' do
      let(:project_allows_to) { false }

      it 'is false' do
        expect(subject).to be_falsey
      end

      it 'is false even if the user is admin' do
        user.admin = true

        expect(subject).to be_falsey
      end
    end

    context 'with having precached the results' do
      before do
        auth_cache = double('auth_cache')

        allow(Users::ProjectAuthorizationCache)
          .to receive(:new)
          .and_return(auth_cache)

        allow(auth_cache)
          .to receive(:cache)
          .with(action)

        allow(auth_cache)
          .to receive(:cached?)
          .with(action)
          .and_return(true)

        Array(context).each do |project|
          allow(auth_cache)
            .to receive(:allowed?)
            .with(action, project)
            .and_return(true)
        end

        instance.preload_projects_allowed_to(action)
      end

      it 'is true' do
        expect(subject).to be_truthy
      end

      it 'does not call the db' do
        subject

        expect(Authorization)
          .not_to have_received(:roles)
      end
    end
  end

  describe '#call' do
    context 'for a project' do
      let(:context) { project }

      it_behaves_like 'allowed to checked'
    end

    context 'for an array of projects' do
      let(:context) { [project, other_project] }

      it_behaves_like 'allowed to checked'

      it 'is false' do
        expect(instance.call(action, [])).to be_falsey
      end

      context 'with one project not allowing an action' do
        before do
          allow(project)
            .to receive(:allows_to?)
            .with(action)
            .and_return(false)
        end

        it 'is false' do
          expect(instance.call(action, [project, other_project])).to be_falsey
        end
      end
    end

    context 'for a relation of projects' do
      let(:context) { double('relation', class: ActiveRecord::Relation, to_a: [project]) }

      it_behaves_like 'allowed to checked'
    end

    context 'for anything else' do
      let(:context) { nil }

      it 'is false' do
        expect(subject).to be_falsey
      end
    end

    context 'for a global check' do
      context 'with the user being admin' do
        before do
          user.admin = true
        end

        it 'is true' do
          expect(instance.call(action, nil, global: true)).to be_truthy
        end
      end

      context 'with the user having a granting role' do
        before do
          allow(Authorization)
            .to receive(:roles)
            .with(user, nil)
            .and_return(user_roles_in_project)

          allow(role)
            .to receive(:allowed_to?)
            .with(action)
            .and_return(true)
        end

        context 'but the user not being active' do
          before do
            user.lock
          end

          it 'is unsuccessful', :aggregate_failures do
            expect(instance.call(action, nil, global: true)).not_to be_truthy
          end
        end

        it 'is successful', :aggregate_failures do
          expect(instance.call(action, nil, global: true)).to be_truthy
        end
      end

      context 'with the user not having a granting role' do
        before do
          allow(Authorization)
            .to receive(:roles)
            .with(user, nil)
            .and_return(user_roles_in_project)

          allow(role)
            .to receive(:allowed_to?)
            .with(action)
            .and_return(false)
        end

        it 'is false' do
          expect(instance.call(action, nil, global: true)).to be_falsey
        end
      end
    end
  end
end
