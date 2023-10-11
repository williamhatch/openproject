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
require_module_spec_helper

RSpec.describe API::V3::Storages::StorageRepresenter, 'rendering' do
  let(:oauth_application) { build_stubbed(:oauth_application) }
  let(:oauth_client_credentials) { build_stubbed(:oauth_client) }
  let(:storage) { build_stubbed(:nextcloud_storage, oauth_application:, oauth_client: oauth_client_credentials) }
  let(:user) { build_stubbed(:user) }
  let(:representer) { described_class.new(storage, current_user: user, embed_links: true) }
  let(:connection_manager) { instance_double(OAuthClients::ConnectionManager) }

  subject(:generated) { representer.to_json }

  before do
    allow(OAuthClients::ConnectionManager)
      .to receive(:new).and_return(connection_manager)
    allow(connection_manager)
      .to receive_messages(authorization_state: :connected, get_authorization_uri: 'https://example.com/authorize')
  end

  describe '_links' do
    describe 'self' do
      it_behaves_like 'has a titled link' do
        let(:link) { 'self' }
        let(:href) { "/api/v3/storages/#{storage.id}" }
        let(:title) { storage.name }
      end
    end

    describe 'origin' do
      it_behaves_like 'has an untitled link' do
        let(:link) { 'origin' }
        let(:href) { storage.host }
      end
    end

    describe 'connectionState' do
      it_behaves_like 'has a titled link' do
        let(:link) { 'authorizationState' }
        let(:href) { 'urn:openproject-org:api:v3:storages:authorization:Connected' }
        let(:title) { 'Connected' }
      end
    end

    describe 'prepareUpload' do
      context 'when user has no :manage_file_links permission on any projects linked to the storage' do
        it 'is empty' do
          expect(generated).to have_json_path('_links/prepareUpload')
          expect(generated).to have_json_size(0).at_path('_links/prepareUpload')
        end
      end

      context 'when user has :manage_file_links permission on some projects linked to the storage' do
        let(:oauth_application) { create(:oauth_application) }
        let(:oauth_client_credentials) { create(:oauth_client) }
        let(:storage) { create(:nextcloud_storage, oauth_application:, oauth_client: oauth_client_credentials) }
        let(:user) { create(:user) }
        let(:another_user) { create(:user) }
        let(:no_permissions_role) { create(:project_role, permissions: []) }
        let(:uploader_role) { create(:project_role, permissions: [:manage_file_links]) }

        # rubocop:disable RSpec/ExampleLength
        it 'contains upload information for each of these projects' do
          project_linked_with_upload_permission =
            create(:project, name: 'project linked, user member with upload permission').tap do |project|
              create(:project_storage, project:, storage:, creator: user)
              create(:member, user:, project:, roles: [uploader_role])
            end
          another_project_linked_with_upload_permission =
            create(:project, name: 'another project linked, user member with upload permission').tap do |project|
              create(:project_storage, project:, storage:, creator: user)
              create(:member, user:, project:, roles: [uploader_role])
            end
          create(:project, name: 'project linked, no permissions').tap do |project|
            create(:project_storage, project:, storage:, creator: user)
            create(:member, user:, project:, roles: [no_permissions_role])
          end
          create(:project, name: 'project linked, user not member').tap do |project|
            create(:project_storage, project:, storage:, creator: user)
          end
          create(:project, active: false, name: 'archived project linked, user member with upload permission').tap do |project|
            create(:project_storage, project:, storage:, creator: user)
            create(:member, user:, project:, roles: [uploader_role])
          end
          create(:project, name: 'project linked, another user is member with upload permission').tap do |project|
            create(:project_storage, project:, storage:, creator: user)
            create(:member, user: another_user, project:, roles: [uploader_role])
          end
          create(:project, name: 'project not linked, with upload permission').tap do |project|
            create(:member, user:, project:, roles: [uploader_role])
          end

          expect(generated).to have_json_size(2).at_path('_links/prepareUpload')

          project_ids = JSON.parse(generated).dig('_links', 'prepareUpload').map { _1.dig('payload', 'projectId') }
          expect(project_ids)
            .to contain_exactly(project_linked_with_upload_permission.id, another_project_linked_with_upload_permission.id)
        end
        # rubocop:enable RSpec/ExampleLength
      end
    end

    describe 'oauthApplication' do
      it_behaves_like 'has no link' do
        let(:link) { 'oauthApplication' }
      end

      context 'as admin' do
        let(:user) { build_stubbed(:admin) }

        it_behaves_like 'has a titled link' do
          let(:link) { 'oauthApplication' }
          let(:href) { "/api/v3/oauth_applications/#{oauth_application.id}" }
          let(:title) { oauth_application.name }
        end

        context 'with invalid configured storage with missing oauth application' do
          let(:oauth_application) { nil }

          it_behaves_like 'has an untitled link' do
            let(:link) { 'oauthApplication' }
            let(:href) { nil }
          end
        end
      end
    end

    describe 'oauthClientCredentials' do
      it_behaves_like 'has no link' do
        let(:link) { 'oauthClientCredentials' }
      end

      context 'as admin' do
        let(:user) { build_stubbed(:admin) }

        it_behaves_like 'has an untitled link' do
          let(:link) { 'oauthClientCredentials' }
          let(:href) { "/api/v3/oauth_client_credentials/#{oauth_client_credentials.id}" }
        end
      end

      context 'as admin without oauth client credentials set' do
        let(:user) { build_stubbed(:admin) }
        let(:oauth_client_credentials) { nil }

        it_behaves_like 'has an untitled link' do
          let(:link) { 'oauthClientCredentials' }
          let(:href) { nil }
        end
      end
    end
  end

  describe '_embedded' do
    describe 'oauthApplication' do
      it { is_expected.not_to have_json_path('_embedded/oauthApplication') }

      context 'as admin' do
        let(:user) { build_stubbed(:admin) }

        it { is_expected.to be_json_eql(oauth_application.id).at_path('_embedded/oauthApplication/id') }
      end
    end

    describe 'oauthClientCredentials' do
      it { is_expected.not_to have_json_path('_embedded/oauthClientCredentials') }

      context 'as admin' do
        let(:user) { build_stubbed(:admin) }

        it { is_expected.to be_json_eql(oauth_client_credentials.id).at_path('_embedded/oauthClientCredentials/id') }
      end

      context 'as admin without oauth client credentials set' do
        let(:user) { build_stubbed(:admin) }
        let(:oauth_client_credentials) { nil }

        it { is_expected.not_to have_json_path('_embedded/oauthClientCredentials') }
      end
    end
  end

  describe 'properties' do
    it_behaves_like 'property', :_type do
      let(:value) { 'Storage' }
    end

    it_behaves_like 'property', :id do
      let(:value) { storage.id }
    end

    it_behaves_like 'datetime property', :createdAt do
      let(:value) { storage.created_at }
    end

    it_behaves_like 'datetime property', :updatedAt do
      let(:value) { storage.updated_at }
    end

    describe 'Automatically managed project folders' do
      shared_examples 'protects applicationPassword' do
        it 'does not render the applicationPassword' do
          expect(generated).not_to have_json_path('applicationPassword')
        end
      end

      context 'with automatic project folder management enabled' do
        let(:storage) do
          build(:nextcloud_storage, :as_automatically_managed, oauth_application:, oauth_client: oauth_client_credentials)
        end

        it_behaves_like 'property', :hasApplicationPassword do
          let(:value) { true }
        end

        it_behaves_like 'protects applicationPassword'
      end

      context 'with automatic project folder management disabled' do
        let(:storage) do
          build(:nextcloud_storage, :as_not_automatically_managed, oauth_application:, oauth_client: oauth_client_credentials)
        end

        it_behaves_like 'property', :hasApplicationPassword do
          let(:value) { false }
        end

        it_behaves_like 'protects applicationPassword'
      end

      context 'when automatic project folder management is not configured' do
        let(:storage) do
          build(:nextcloud_storage, provider_fields: {}, oauth_application:, oauth_client: oauth_client_credentials)
        end

        it 'hasApplicationPassword is false' do
          expect(generated).to be_json_eql(false).at_path('hasApplicationPassword')
        end

        it_behaves_like 'protects applicationPassword'
      end

      context 'with a non-Nextcloud storage' do
        let(:storage) do
          build(:one_drive_storage, oauth_application:, oauth_client: oauth_client_credentials)
        end

        before do
          Storages::Peripherals::Registry.stub('queries.one_drive.open_drive_link', ->(_) do
            ServiceResult.success(result: 'https://my.sharepoint.com/sites/DeathStar/Documents')
          end)
        end

        it 'does not include the property hasApplicationPassword' do
          expect(generated).not_to have_json_path('hasApplicationPassword')
        end

        it_behaves_like 'protects applicationPassword'
      end
    end
  end
end
