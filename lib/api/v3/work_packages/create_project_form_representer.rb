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

module API
  module V3
    module WorkPackages
      class CreateProjectFormRepresenter < FormRepresenter
        link :self do
          {
            href: api_v3_paths.create_project_work_package_form(represented.project_id),
            method: :post
          }
        end

        link :validate do
          {
            href: api_v3_paths.create_project_work_package_form(represented.project_id),
            method: :post
          }
        end

        link :previewMarkup do
          {
            href: api_v3_paths.render_markup(link: api_v3_paths.project(represented.project_id)),
            method: :post
          }
        end

        link :commit do
          if current_user.allowed_in_work_package?(:edit_work_packages, represented) && @errors.empty?
            {
              href: api_v3_paths.work_packages_by_project(represented.project_id),
              method: :post
            }
          end
        end

        link :customFields do
          if current_user.allowed_in_project?(:select_custom_fields, represented.project)
            {
              href: project_settings_custom_fields_path(represented.project.identifier),
              type: 'text/html',
              title: I18n.t('label_custom_field_plural')
            }
          end
        end

        link :configureForm do
          if current_user.admin? &&
             represented.type_id &&
             represented.type_id != 0
            {
              href: edit_type_path(represented.type_id,
                                   tab: 'form_configuration'),
              type: 'text/html',
              title: "Configure form"
            }
          end
        end
      end
    end
  end
end
