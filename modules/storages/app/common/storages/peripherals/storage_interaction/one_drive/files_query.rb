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

module Storages
  module Peripherals
    module StorageInteraction
      module OneDrive
        class FilesQuery
          FIELDS = "?$select=id,name,size,webUrl,lastModifiedBy,createdBy,fileSystemInfo,file,folder,parentReference"

          using ServiceResultRefinements

          def self.call(storage:, user:, folder:)
            new(storage).call(user:, folder:)
          end

          def initialize(storage)
            @storage = storage
            @uri = storage.uri
          end

          def call(user:, folder: nil)
            result = Util.using_user_token(@storage, user) do |token|
              # Make the Get Request to the necessary endpoints
              response = Net::HTTP.start(@uri.host, @uri.port, use_ssl: true) do |http|
                http.get(uri_path_for(folder) + FIELDS, { 'Authorization' => "Bearer #{token.access_token}" })
              end

              handle_response(response)
            end

            if result.result.empty?
              empty_response(folder)
            else
              result.map { |json_files| storage_files(json_files) }
            end
          end

          private

          def handle_response(response)
            json = MultiJson.load(response.body, symbolize_keys: true)
            error_data = ::Storages::StorageErrorData.new(source: self, payload: json)

            case response
            when Net::HTTPSuccess
              ServiceResult.success(result: MultiJson.load(response.body, symbolize_keys: true)[:value])
            when Net::HTTPNotFound
              ServiceResult.failure(result: :not_found,
                                    errors: ::Storages::StorageError.new(code: :not_found, data: error_data))
            when Net::HTTPUnauthorized
              ServiceResult.failure(result: :unauthorized,
                                    errors: ::Storages::StorageError.new(code: :unauthorized, data: error_data))
            else
              ServiceResult.failure(result: :error,
                                    errors: ::Storages::StorageError.new(code: :error, data: error_data))
            end
          end

          def storage_files(json_files)
            files = json_files.map { |json| storage_file(json) }

            parent_reference = json_files.first[:parentReference]
            StorageFiles.new(files, parent(parent_reference), forge_ancestors(parent_reference))
          end

          def storage_file(json_file)
            StorageFile.new(
              id: json_file[:id],
              name: json_file[:name],
              size: json_file[:size],
              mime_type: Util.mime_type(json_file),
              created_at: Time.zone.parse(json_file.dig(:fileSystemInfo, :createdDateTime)),
              last_modified_at: Time.zone.parse(json_file.dig(:fileSystemInfo, :lastModifiedDateTime)),
              created_by_name: json_file.dig(:createdBy, :user, :displayName),
              last_modified_by_name: json_file.dig(:lastModifiedBy, :user, :displayName),
              location: extract_location(json_file[:parentReference], json_file[:name]),
              permissions: %i[readable writeable]
            )
          end

          def empty_response(folder)
            ServiceResult.success(
              result: StorageFiles.new(
                [],
                StorageFile.new(
                  id: Digest::SHA256.hexdigest(folder),
                  name: folder.split('/').last,
                  location: folder,
                  permissions: %i[readable writeable]
                ),
                forge_ancestors(path: folder)
              )
            )
          end

          def extract_location(parent_reference, file_name = '')
            location = parent_reference[:path].gsub(/.*root:/, '')

            appendix = file_name.blank? ? '' : "/#{file_name}"
            location.empty? ? "/#{file_name}" : "#{location}#{appendix}"
          end

          def parent(parent_reference)
            _, _, name = parent_reference[:path].gsub(/.*root:/, '').rpartition '/'

            if name.empty?
              root(parent_reference[:id])
            else
              StorageFile.new(
                id: parent_reference[:id],
                name:,
                location: extract_location(parent_reference),
                permissions: %i[readable writeable]
              )
            end
          end

          def forge_ancestors(parent_reference)
            path_elements = parent_reference[:path].gsub(/.+root:/, '').split('/')

            path_elements[0..-2].map do |component|
              next root(Digest::SHA256.hexdigest('i_am_root')) if component.blank?

              StorageFile.new(
                id: Digest::SHA256.hexdigest(component),
                name: component,
                location: "/#{component}"
              )
            end
          end

          def root(id)
            StorageFile.new(name: "Root",
                            location: "/",
                            id:,
                            permissions: %i[readable writeable])
          end

          def uri_path_for(folder)
            return "/v1.0/drives/#{@storage.drive_id}/root/children" unless folder

            "/v1.0/drives/#{@storage.drive_id}/root:#{encode_path(folder)}:/children"
          end

          def encode_path(path)
            path.split('/').map { |fragment| URI.encode_uri_component(fragment) }.join('/')
          end
        end
      end
    end
  end
end
