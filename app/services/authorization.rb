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

module Authorization
  module_function

  # Returns all users having a certain permission within a project
  def users(action, project)
    Authorization::UserAllowedQuery.query(action, project)
  end

  # Returns all projects a user has a certain permission in
  def projects(action, user)
    Project.allowed_to(user, action)
  end

  # Returns all work packages a user has a certain permission in (or in the project it belongs to)
  def work_packages(action, user)
    WorkPackage.allowed_to(user, action)
  end

  # Returns all roles a user has in a certain project, for a specific entity or globally
  def roles(user, context = nil)
    if context.is_a?(Project)
      Authorization::UserProjectRolesQuery.query(user, context)
    elsif Member.can_be_member_of?(context)
      Authorization::UserEntityRolesQuery.query(user, context)
    else
      Authorization::UserGlobalRolesQuery.query(user)
    end
  end

  # Normalizes the different types of permission arguments into Permission objects.
  # Possible arguments
  #  - Symbol permission names (e.g. :view_work_packages)
  #  - Hash with :controller and :action (e.g. { controller: 'work_packages', action: 'show' })
  def permissions_for(action)
    return [action] if action.is_a?(OpenProject::AccessControl::Permission)
    return action if action.is_a?(Array) && action.all?(OpenProject::AccessControl::Permission)

    if action.is_a?(Hash)
      OpenProject::AccessControl.allow_actions(action)
    else
      [OpenProject::AccessControl.permission(action)].compact
    end
  end

  # Returns a set of normalized permissions filtered for a given context
  #  - When there is no permission matching the +permission+ parameter, either an empty array is returned
  #    or an +UnknownPermissionError+ is raised (depending on the raise_on_unknown parameter).
  #    If the permission is disabled, it will never raise an error.
  #  - When there are no permissions available for the given context (based on +permissible_on+
  #    attribute of the permission), an +IllegalPermissionContextError+ is raised
  def contextual_permissions(action, context, raise_on_unknown: false)
    perms = permissions_for(action)

    if perms.blank?
      Rails.logger.debug { "Used permission \"#{action}\" that is not defined. It will never return true." }
      raise UnknownPermissionError.new(action) if raise_on_unknown && !OpenProject::AccessControl.disabled_permission?(action)

      return []
    end

    context_perms = perms.select { |p| p.permissible_on?(context) }
    raise IllegalPermissionContextError.new(action, perms, context) if context_perms.blank?

    context_perms
  end
end
