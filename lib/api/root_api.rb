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

# Root class of the API
# This is the place for all API wide configuration, helper methods, exceptions
# rescuing, mounting of different API versions etc.

require 'open_project/authentication'

module API
  class RootAPI < Grape::API
    include OpenProject::Authentication::Scope
    include ::API::AppsignalAPI
    extend API::Utilities::GrapeHelper

    insert_before Grape::Middleware::Error,
                  ::GrapeLogging::Middleware::RequestLogger,
                  { instrumentation_key: 'openproject_grape_logger' }

    content_type :json, 'application/json; charset=utf-8'

    use OpenProject::Authentication::Manager

    helpers API::Caching::Helpers
    module Helpers
      def current_user
        User.current
      end

      def warden
        env['warden']
      end

      ##
      # Helper to access only the declared
      # params to avoid unvalidated access
      # (e.g., in before blocks)
      def declared_params
        declared(params)
      end

      def request_body
        env['api.request.body']
      end

      def authenticate
        User.current = warden.authenticate! scope: authentication_scope

        if Setting.login_required? && !logged_in? && !allowed_unauthenticated_route?
          raise ::API::Errors::Unauthenticated
        end
      end

      def allowed_unauthenticated_route?
        false
      end

      def set_localization
        SetLocalizationService.new(User.current, env['HTTP_ACCEPT_LANGUAGE']).call
      end

      # Global helper to set allowed content_types
      # This may be overridden when multipart is allowed (file uploads)
      def allowed_content_types
        %w(application/json application/hal+json)
      end

      def enforce_content_type
        # Content-Type is not present in GET
        return if request.get?

        # Raise if missing header
        content_type = request.content_type
        error!('Missing content-type header', 406, { 'Content-Type' => 'text/plain' }) if content_type.blank?

        # Allow JSON and JSON+HAL per default
        # and anything that each endpoint may optionally add to that
        if content_type.present?
          allowed_content_types.each do |mime|
            # Content-Type header looks like this (e.g.,)
            # application/json;encoding=utf8
            return if content_type.start_with?(mime)
          end
        end

        bad_type = content_type.presence || I18n.t('api_v3.errors.missing_content_type')
        message = I18n.t('api_v3.errors.invalid_content_type',
                         content_type: allowed_content_types.join(" "),
                         actual: bad_type)

        fail ::API::Errors::UnsupportedMediaType, message
      end

      def logged_in?
        # An admin SystemUser is anonymous but still a valid user to be logged in.
        current_user && (current_user.admin? || !current_user.anonymous?)
      end

      # Checks that the current user has the given permission or raise
      # {API::Errors::Unauthorized}.
      #
      # @param permission [String] the permission name
      #
      # @param context [Project, Array<Project>, nil] can be:
      #   * a project : returns true if user is allowed to do the specified
      #     action on this project
      #   * a group of projects : returns true if user is allowed on every
      #     project
      #   * +nil+ with +options[:global]+ set: check if user has at least one
      #     role allowed for this action, or falls back to Non Member /
      #     Anonymous permissions depending if the user is logged
      #
      # @param global [Boolean] when +true+ and with +context+ set to +nil+:
      #   checks that the current user is allowed to do the specified action on
      #   any project
      #
      # @raise [API::Errors::Unauthorized] when permission is not met
      def authorize(permission, context: nil, global: false, user: current_user, &block)
        # TODO: Refactor
        auth_service = -> { user.allowed_to?(permission, context, global:) }
        authorize_by_with_raise auth_service, &block
      end

      def authorize_by_with_raise(callable)
        is_authorized = callable.respond_to?(:call) ? callable.call : callable

        return true if is_authorized

        if block_given?
          yield
        else
          raise API::Errors::Unauthorized
        end

        false
      end

      # checks whether the user has
      # any of the provided permission in any of the provided
      # projects
      def authorize_any(permissions, projects: nil, global: false, user: current_user, &block)
        raise ArgumentError if projects.nil? && !global

        projects = Array(projects)

        authorized = permissions.any? do |permission|
          if global
            authorize(permission, global: true, user:) do
              false
            end
          else
            allowed_projects = Project.allowed_to(user, permission)
            !(allowed_projects & projects).empty?
          end
        end

        authorize_by_with_raise(authorized, &block)
      end

      def authorize_admin
        authorize_by_with_raise(current_user.admin? && (current_user.active? || current_user.is_a?(SystemUser)))
      end

      def authorize_logged_in
        authorize_by_with_raise((current_user.logged? && current_user.active?) || current_user.is_a?(SystemUser))
      end

      def raise_query_errors(object)
        api_errors = object.errors.full_messages.map do |message|
          ::API::Errors::InvalidQuery.new(message)
        end

        raise ::API::Errors::MultipleErrors.create_if_many api_errors
      end

      def raise_invalid_query_on_service_failure
        service = yield

        if service.success?
          service
        else
          raise_query_errors(service)
        end
      end
    end

    helpers Helpers

    def self.auth_headers
      lambda do
        header = OpenProject::Authentication::WWWAuthenticate
                   .response_header(scope: authentication_scope, request_headers: env)

        { 'WWW-Authenticate' => header }
      end
    end

    def self.error_representer(klass, content_type)
      # Have the vars available in the instances via helpers.
      helpers do
        define_method(:error_representer, -> { klass })
        define_method(:error_content_type, -> { content_type })
      end
    end

    def self.authentication_scope(sym)
      # Have the scope available in the instances
      # via a helper.
      helpers do
        define_method(:authentication_scope, -> { sym })
      end
    end

    error_response ActiveRecord::RecordNotFound, ::API::Errors::NotFound, log: false
    error_response ActiveRecord::StaleObjectError, ::API::Errors::Conflict, log: false
    error_response NotImplementedError, ::API::Errors::NotImplemented, log: false

    error_response MultiJson::ParseError, ::API::Errors::ParseError

    error_response ::API::Errors::Unauthenticated, headers: auth_headers, log: false
    error_response ::API::Errors::ErrorBase, rescue_subclasses: true, log: false

    # Handle grape validation errors
    error_response ::Grape::Exceptions::ValidationErrors, ::API::Errors::BadRequest, log: false

    # Handle connection timeouts with appropriate payload
    error_response ActiveRecord::ConnectionTimeoutError,
                   ::API::Errors::InternalError,
                   log: ->(exception) do
                     payload = ::OpenProject::Logging::ThreadPoolContextBuilder.build!
                     ::OpenProject.logger.error exception, reference: :APIv3, payload:
                   end

    # hide internal errors behind the same JSON response as all other errors
    # only doing it in production to allow for easier debugging
    if Rails.env.production?
      error_response StandardError, ::API::Errors::InternalError, rescue_subclasses: true
    end

    # run authentication before each request
    after_validation do
      authenticate
      set_localization
      enforce_content_type
      ::OpenProject::Appsignal.tag_request(request:)
    end
  end
end
