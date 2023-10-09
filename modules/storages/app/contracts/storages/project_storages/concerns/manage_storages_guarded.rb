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

# Purpose: This is a "concern" to check if a user is authorized to
# Manage Storages and guard against unauthorized users.
# See also: Storages::Storages::Concerns::ManageStoragesGuarded for more details
module Storages::ProjectStorages
  module Concerns
    module ManageStoragesGuarded
      extend ActiveSupport::Concern

      included do
        validate :validate_user_allowed_to_manage

        private

        # Check that the current has the permission on the project.
        # model variable is available because the concern is executed inside a contract.
        def validate_user_allowed_to_manage
          unless user.allowed_in_project?(:manage_storages_in_project, model.project)
            errors.add :base, :error_unauthorized
          end
        end
      end
    end
  end
end
