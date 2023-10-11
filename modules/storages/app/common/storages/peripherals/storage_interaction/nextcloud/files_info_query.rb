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

module Storages::Peripherals::StorageInteraction::Nextcloud
  class FilesInfoQuery
    using Storages::Peripherals::ServiceResultRefinements

    FILES_INFO_PATH = 'ocs/v1.php/apps/integration_openproject/filesinfo'

    def initialize(storage)
      @uri = storage.uri
      @configuration = storage.oauth_configuration
    end

    def self.call(storage:, user:, file_ids: [])
      new(storage).call(user:, file_ids:)
    end

    def call(user:, file_ids: [])
      if file_ids.nil?
        return Util.error(:error, 'File IDs can not be nil', file_ids)
      end

      if file_ids.empty?
        return ServiceResult.success(result: [])
      end

      Util.token(user:, configuration: @configuration) do |token|
        files_info(file_ids, token).map(&parse_json) >> handle_failure >> create_storage_file_infos
      end
    end

    private

    def files_info(file_ids, token)
      response = Util.http(@uri).post(
        Util.join_uri_path(@uri.path, FILES_INFO_PATH),
        { fileIds: file_ids }.to_json,
        {
          'Authorization' => "Bearer #{token.access_token}",
          'Accept' => 'application/json',
          'Content-Type' => 'application/json',
          'OCS-APIRequest' => 'true'
        }
      )
      case response
      when Net::HTTPSuccess
        ServiceResult.success(result: response.body)
      when Net::HTTPNotFound
        Util.error(:not_found, 'Outbound request destination not found!', response)
      when Net::HTTPUnauthorized
        Util.error(:unauthorized, 'Outbound request not authorized!', response)
      else
        Util.error(:error, 'Outbound request failed!')
      end
    end

    def parse_json
      ->(response_body) do
        # rubocop:disable Style/OpenStructUse
        JSON.parse(response_body, object_class: OpenStruct)
        # rubocop:enable Style/OpenStructUse
      end
    end

    def handle_failure
      ->(response_object) do
        if response_object.ocs.meta.status == 'ok'
          ServiceResult.success(result: response_object)
        else
          Util.error(:error, 'Outbound request failed!', response_object)
        end
      end
    end

    # rubocop:disable Metrics/AbcSize
    def create_storage_file_infos
      ->(response_object) do
        ServiceResult.success(
          result: response_object.ocs.data.each_pair.map do |key, value|
            if value.statuscode == 200
              ::Storages::StorageFileInfo.new(
                status: value.status,
                status_code: value.statuscode,
                id: value.id,
                name: value.name,
                last_modified_at: Time.zone.at(value.mtime),
                created_at: Time.zone.at(value.ctime),
                mime_type: value.mimetype,
                size: value.size,
                owner_name: value.owner_name,
                owner_id: value.owner_id,
                trashed: value.trashed,
                last_modified_by_name: value.modifier_name,
                last_modified_by_id: value.modifier_id,
                permissions: value.dav_permissions,
                location: location(value.path, value.mimetype)
              )
            else
              ::Storages::StorageFileInfo.new(
                status: value.status,
                status_code: value.statuscode,
                id: key.to_s.to_i
              )
            end
          end
        )
      end
    end

    # rubocop:enable Metrics/AbcSize

    def location(file_path, mimetype)
      prefix = 'files/'
      idx = file_path.rindex(prefix)
      return '/' if idx == nil

      idx += prefix.length - 1
      # Remove the following when /filesinfo starts responding with a trailing slash for directory paths
      # in all supported versions of OpenProjectIntegation Nextcloud App.
      file_path << '/' if mimetype == 'application/x-op-directory' && file_path[-1] != '/'
      Util.escape_path(file_path[idx..])
    end
  end
end
