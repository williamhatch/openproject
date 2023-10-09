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
      class WorkPackageCollectionRepresenter < ::API::Decorators::OffsetPaginatedCollection
        attr_accessor :timestamps, :query

        def initialize(models,
                       self_link:,
                       groups:,
                       total_sums:,
                       current_user:,
                       query_params: {},
                       project: nil,
                       page: nil,
                       per_page: nil,
                       embed_schemas: false,
                       timestamps: [],
                       query: nil)
          @project = project
          @total_sums = total_sums
          @embed_schemas = embed_schemas
          @timestamps = timestamps
          @query = query

          if timestamps_active?
            query_params[:timestamps] ||= API::V3::Utilities::PathHelper::ApiV3Path.timestamps_to_param_value(timestamps)
          end

          super(models,
                self_link:,
                query_params:,
                page:,
                per_page:,
                groups:,
                current_user:)

          # In order to optimize performance we
          #   * override paged_models so that only the id is fetched from the
          #     scope (typically a query with a couple of includes for e.g.
          #     filtering), circumventing AR instantiation altogether
          #   * use the ids to fetch the actual work packages with all the fields
          #     necessary for rendering the work packages in _elements
          #
          # This results in the weird flow where the scope is passed to super (models variable),
          # which calls the overridden paged_models method fetching the ids. In order to have
          # real AR objects again, we finally get the work packages we actually want to have
          # and set those to be the represented collection.
          # A potential ordering is reapplied to the work package collection in ruby.

          @represented = ::API::V3::WorkPackages::WorkPackageEagerLoadingWrapper \
            .wrap(represented, current_user, timestamps:, query:)
        end

        link :sumsSchema do
          next unless total_sums || (groups && groups.any?(&:has_sums?))

          {
            href: api_v3_paths.work_package_sums_schema
          }
        end

        link :editWorkPackage do
          next unless current_user_allowed_to_edit_work_packages?

          {
            href: api_v3_paths.work_package_form('{work_package_id}'),
            method: :post,
            templated: true
          }
        end

        link :createWorkPackage do
          next unless current_user_allowed_to_add_work_packages?

          {
            href: api_v3_paths.create_work_package_form,
            method: :post
          }
        end

        link :createWorkPackageImmediate do
          next unless current_user_allowed_to_add_work_packages?

          {
            href: api_v3_paths.work_packages,
            method: :post
          }
        end

        link :schemas do
          next if represented.empty?

          {
            href: schemas_path
          }
        end

        link :customFields do
          if project.present? && current_user.allowed_in_project?(:select_custom_fields, project)
            {
              href: project_settings_custom_fields_path(project.identifier),
              type: 'text/html',
              title: I18n.t('label_custom_field_plural')
            }
          end
        end

        links :representations do
          representation_formats if current_user.allowed_in_work_package?(:export_work_packages, represented)
        end

        collection :elements,
                   getter: ->(*) {
                     all_fields = represented.map(&:available_custom_fields).flatten.uniq

                     rep_class = element_decorator.custom_field_class(all_fields)

                     represented.map do |model|
                       # In case the work package is no longer visible (moved to a project the user
                       # lacks permission in) we treat it as if the work package were deleted.
                       representer = if model.visible?(current_user)
                                       rep_class
                                     else
                                       WorkPackageDeletedRepresenter
                                     end

                       representer.send(:new, model, current_user:, timestamps:, query:)
                     end
                   },
                   exec_context: :decorator,
                   embedded: true

        property :schemas,
                 exec_context: :decorator,
                 if: ->(*) { embed_schemas && represented.any? },
                 embedded: true,
                 render_nil: false

        property :total_sums,
                 exec_context: :decorator,
                 getter: ->(*) {
                   if total_sums
                     ::API::V3::WorkPackages::WorkPackageSumsRepresenter.create(total_sums, current_user)
                   end
                 },
                 render_nil: false

        def current_user_allowed_to_add_work_packages?
          @current_user_allowed_to_add_work_packages ||= current_user.allowed_in_project?(:add_work_packages, project)
        end

        def current_user_allowed_to_edit_work_packages?
          current_user.allowed_in_work_package?(:edit_work_packages, represented)
        end

        def schemas
          schemas = schema_pairs.map do |project, type, available_custom_fields|
            Schema::TypedWorkPackageSchema.new(project:, type:, custom_fields: available_custom_fields)
          end

          Schema::WorkPackageSchemaCollectionRepresenter.new(schemas,
                                                             self_link: schemas_path,
                                                             current_user:)
        end

        def schemas_path
          ids = schema_pairs.map do |project, type|
            [project.id, type.id]
          end

          api_v3_paths.work_package_schemas(*ids)
        end

        def schema_pairs
          @schema_pairs ||= begin
            work_packages = if timestamps_active?
                              represented
                                .flat_map(&:at_timestamps)
                            else
                              represented
                            end

            work_packages
              .select(&:persisted?)
              .uniq { |work_package| [work_package.project_id, work_package.type_id] }
              .map { |work_package| [work_package.project, work_package.type, work_package.available_custom_fields] }
          end
        end

        def paged_models(models)
          super.pluck(:id)
        end

        def _type
          'WorkPackageCollection'
        end

        def representation_formats
          formats = [
            representation_format_pdf,
            representation_format_pdf_report_with_images,
            representation_format_pdf_report,
            representation_format_xls,
            representation_format_xls_descriptions,
            representation_format_xls_relations,
            representation_format_csv
          ]

          if Setting.feeds_enabled?
            formats << representation_format_atom
          end

          formats
        end

        def representation_format(identifier, mime_type:, format: identifier, i18n_key: format, url_query_extras: nil)
          path_params = { controller: :work_packages, action: :index, project_id: project }

          href = "#{url_for(path_params.merge(format:))}?#{href_query(@page, @per_page)}"

          if url_query_extras
            href += "&#{url_query_extras}"
          end

          {
            href:,
            identifier:,
            type: mime_type,
            title: I18n.t("export.format.#{i18n_key}")
          }
        end

        def representation_format_pdf
          representation_format 'pdf',
                                i18n_key: 'pdf_overview_table',
                                mime_type: 'application/pdf'
        end

        def representation_format_pdf_report_with_images
          representation_format 'pdf-with-descriptions',
                                format: 'pdf',
                                i18n_key: 'pdf_report_with_images',
                                mime_type: 'application/pdf',
                                url_query_extras: 'show_images=true&show_report=true'
        end

        def representation_format_pdf_report
          representation_format 'pdf-descr',
                                format: 'pdf',
                                i18n_key: 'pdf_report',
                                mime_type: 'application/pdf',
                                url_query_extras: 'show_report=true'
        end

        def representation_format_xls
          representation_format 'xls',
                                mime_type: 'application/vnd.ms-excel'
        end

        def representation_format_xls_descriptions
          representation_format 'xls-with-descriptions',
                                i18n_key: 'xls_with_descriptions',
                                mime_type: 'application/vnd.ms-excel',
                                format: 'xls',
                                url_query_extras: 'show_descriptions=true'
        end

        def representation_format_xls_relations
          representation_format 'xls-with-relations',
                                i18n_key: 'xls_with_relations',
                                mime_type: 'application/vnd.ms-excel',
                                format: 'xls',
                                url_query_extras: 'show_relations=true'
        end

        def representation_format_csv
          representation_format 'csv',
                                mime_type: 'text/csv'
        end

        def representation_format_atom
          representation_format 'atom',
                                mime_type: 'application/atom+xml'
        end

        def timestamps_active?
          timestamps.present? && timestamps.any?(&:historic?)
        end

        attr_reader :project,
                    :total_sums,
                    :embed_schemas
      end
    end
  end
end
