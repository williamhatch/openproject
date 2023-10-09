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

module PlaceholderUsers
  class BaseContract < ::ModelContract
    # attribute_alias is broken in the sense
    # that `model#changed` includes only the non-aliased name
    # hence we need to put "lastname" as an attribute here
    attribute :name
    attribute :lastname

    def self.model
      PlaceholderUser
    end

    validate :user_allowed_to_modify

    protected

    ##
    # Placeholder users can only be updated by Admins
    def user_allowed_to_modify
      unless user_allowed_to_add?
        errors.add :base, :error_unauthorized
      end
    end

    def user_allowed_to_add?
      user.allowed_globally?(:manage_placeholder_user)
    end
  end
end
