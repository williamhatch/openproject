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

module WorkPackages
  module Share
    class PermissionButtonComponent < ApplicationComponent
      include ApplicationHelper
      include OpPrimer::ComponentHelpers

      def initialize(share:, **system_arguments)
        super

        @share = share
        @system_arguments = system_arguments
      end

      # Switches the component to either update the share directly (by sending a PATCH to the share path)
      # or be passive and work like a select inside a form.
      def update_path
        if share.persisted?
          work_packages_share_path(share)
        end
      end

      def option_active?(option)
        option[:value] == active_role.builtin
      end

      private

      attr_reader :share

      def options
        [
          { label: I18n.t('work_package.sharing.permissions.edit'),
            value: Role::BUILTIN_WORK_PACKAGE_EDITOR,
            description: I18n.t('work_package.sharing.permissions.edit_description') },
          { label: I18n.t('work_package.sharing.permissions.comment'),
            value: Role::BUILTIN_WORK_PACKAGE_COMMENTER,
            description: I18n.t('work_package.sharing.permissions.comment_description') },
          { label: I18n.t('work_package.sharing.permissions.view'),
            value: Role::BUILTIN_WORK_PACKAGE_VIEWER,
            description: I18n.t('work_package.sharing.permissions.view_description') }
        ]
      end

      def active_role
        if share.persisted?
          share.roles
               .joins(:member_roles)
               .where(member_roles: { inherited_from: nil })
               .first
        else
          share.roles.first
        end
      end

      def permission_name(value)
        options.select { |option| option[:value] == value }
      end
    end
  end
end
