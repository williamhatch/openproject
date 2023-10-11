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

FactoryBot.define do
  factory :principal do
    transient do
      member_in_project { nil }
      member_in_projects { nil }
      member_through_role { nil }
      member_with_permissions { nil }

      global_role { nil }
      global_permission { nil }
    end

    # prevent forgetting :member_in_project(s) when using :member_through_role
    # or :member_with_permissions for a better DX
    after(:build, :create, :stub) do |principal, evaluator|
      next if %i[member_in_project member_in_projects].any? { |attr| evaluator.overrides?(attr) }

      unusable_attribute = %i[member_through_role member_with_permissions].find { |attr| evaluator.send(attr).present? }
      next unless unusable_attribute

      raise ArgumentError, "Cannot use :#{unusable_attribute} without :member_in_project or :member_in_projects " \
                           "for #{principal.class} factory"
    end

    callback(:after_build) do |_principal, evaluator|
      is_build_strategy = evaluator.instance_eval { @build_strategy.is_a? FactoryBot::Strategy::Build }
      uses_member_association = evaluator.member_in_project || evaluator.member_in_projects
      if is_build_strategy && uses_member_association
        raise ArgumentError, "Use create(...) with principals and member_in_project(s) traits."
      end
    end

    callback(:after_create) do |principal, evaluator|
      (projects = evaluator.member_in_projects || [])
      projects << evaluator.member_in_project if evaluator.member_in_project
      if projects.any?
        role = evaluator.member_through_role || build(:project_role,
                                                      permissions: evaluator.member_with_permissions || %i[
                                                        view_work_packages edit_work_packages
                                                      ])
        projects.compact.each do |project|
          create(:member,
                 project:,
                 principal:,
                 roles: Array(role))
        end
      end
    end

    callback(:after_create) do |principal, evaluator|
      if evaluator.global_permission || evaluator.global_role
        permissions = Array(evaluator.global_permission)
        global_role = evaluator.global_role || create(:global_role, permissions:)

        create(:global_member,
               principal:,
               roles: [global_role])

      end
    end
  end
end
