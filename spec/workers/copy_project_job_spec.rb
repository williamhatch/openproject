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

require 'spec_helper'

RSpec.describe CopyProjectJob, type: :model do
  let(:project) { create(:project, public: false) }
  let(:user) { create(:user) }
  let(:role) { create(:project_role, permissions: [:copy_projects]) }
  let(:params) { { name: 'Copy', identifier: 'copy' } }
  let(:maildouble) { double('Mail::Message', deliver: true) }

  before do
    allow(maildouble).to receive(:deliver_later)
  end

  describe 'copy localizes error message' do
    let(:user_de) { create(:admin, language: :de) }
    let(:source_project) { create(:project) }
    let(:target_project) { create(:project) }

    let(:copy_job) do
      described_class.new
    end

    it 'sets locale correctly' do
      expect(copy_job)
        .to receive(:create_project_copy)
              .and_wrap_original do |m, *args, &block|
        expect(I18n.locale).to eq(:de)
        m.call(*args, &block)
      end

      copy_job.perform user_id: user_de.id,
                       source_project_id: source_project.id,
                       target_project_params: {},
                       associations_to_copy: []
    end
  end

  describe 'copy project succeeds with errors' do
    let(:admin) { create(:admin) }
    let(:source_project) { create(:project, types: [type]) }
    let!(:work_package) { create(:work_package, project: source_project, type:) }
    let(:type) { create(:type_bug) }
    let(:custom_field) do
      create(:work_package_custom_field,
             name: 'required_field',
             field_format: 'text',
             is_required: true,
             is_for_all: true)
    end
    let(:job_args) do
      {
        user_id: admin.id,
        source_project_id: source_project.id,
        target_project_params: params,
        associations_to_copy: [:work_packages]
      }
    end
    let(:copy_job) do
      described_class.new(**job_args).tap(&:perform_now)
    end

    let(:params) { { name: 'Copy', identifier: 'copy', type_ids: [type.id], work_package_custom_field_ids: [custom_field.id] } }
    let(:expected_error_message) do
      "#{WorkPackage.model_name.human} '#{work_package.type.name} ##{work_package.id}: #{work_package.subject}': #{custom_field.name} #{I18n.t('errors.messages.blank')}."
    end

    # rubocop:disable RSpec/InstanceVariable
    before do
      source_project.work_package_custom_fields << custom_field
      type.custom_fields << custom_field

      allow(User).to receive(:current).and_return(admin)

      @copied_project = copy_job.target_project
      @errors = copy_job.errors
    end

    it 'copies the project', :aggregate_failures do
      expect(Project.find_by(identifier: params[:identifier])).to eq(@copied_project)
      expect(@errors.first).to eq(expected_error_message)

      # expect to create a status
      expect(copy_job.job_status).to be_present
      expect(copy_job.job_status[:status]).to eq 'success'
      expect(copy_job.job_status[:payload]['redirect']).to include '/projects/copy'

      expected_link = { 'href' => "/api/v3/projects/#{@copied_project.id}", 'title' => @copied_project.name }
      expect(copy_job.job_status[:payload]['_links']['project']).to eq(expected_link)
    end
  end
  # rubocop:enable RSpec/InstanceVariable

  describe 'project has an invalid repository' do
    let(:admin) { create(:admin) }
    let(:source_project) do
      project = create(:project)

      # add invalid repo
      repository = Repository::Git.new(scm_type: :existing, project:)
      repository.save!(validate: false)
      project.reload
      project
    end

    let(:copy_job) do
      described_class.new.tap do |job|
        job.perform user_id: admin.id,
                    source_project_id: source_project.id,
                    target_project_params: params,
                    associations_to_copy: [:work_packages]
      end
    end

    before do
      allow(User).to receive(:current).and_return(admin)
    end

    it 'saves without the repository' do
      expect(source_project).not_to be_valid

      copied_project = copy_job.target_project
      errors = copy_job.errors

      expect(errors).to be_empty
      expect(copied_project).to be_valid
      expect(copied_project.repository).to be_nil
      expect(copied_project.enabled_module_names).not_to include 'repository'
    end
  end

  describe 'copy project fails with internal error' do
    let(:admin) { create(:admin) }
    let(:source_project) { create(:project) }
    let(:copy_job) do
      described_class.new.tap do |job|
        job.perform user_id: admin.id,
                    source_project_id: source_project.id,
                    target_project_params: params,
                    associations_to_copy: [:work_packages]
      end
    end

    let(:params) { { name: 'Copy', identifier: 'copy' } }

    before do
      allow(User).to receive(:current).and_return(admin)
      allow(ProjectMailer).to receive(:copy_project_succeeded).and_raise 'error message not meant for user'
    end

    it 'renders a error when unexpected errors occur' do
      expect(ProjectMailer)
        .to receive(:copy_project_failed)
              .with(admin, source_project, 'Copy', [I18n.t('copy_project.failed_internal')])
              .and_return maildouble

      expect { copy_job }.not_to raise_error

      # expect to create a status
      expect(copy_job.job_status).to be_present
      expect(copy_job.job_status[:status]).to eq 'failure'
      expect(copy_job.job_status[:message]).to include "Cannot copy project #{source_project.name}"
      expect(copy_job.job_status[:payload]).to eq('title' => 'Copy project')
    end
  end

  shared_context 'copy project' do
    before do
      described_class.new.tap do |job|
        job.perform user_id: user.id,
                    source_project_id: project_to_copy.id,
                    target_project_params: params,
                    associations_to_copy: [:members]
      end
    end
  end

  describe 'perform' do
    before do
      login_as(user)
      expect(User).to receive(:current=).with(user).at_least(:once)
    end

    describe 'subproject' do
      let(:params) { { name: 'Copy', identifier: 'copy' } }
      let(:subproject) do
        create(:project, parent: project).tap do |p|
          create(:member,
                 principal: user,
                 roles: [role],
                 project: p)
        end
      end

      subject { Project.find_by(identifier: 'copy') }

      describe 'user without add_subprojects permission in parent' do
        include_context 'copy project' do
          let(:project_to_copy) { subproject }
        end

        it 'copies the project without the parent being set' do
          expect(subject).not_to be_nil
          expect(subject.parent).to be_nil

          expect(subproject.reload.enabled_module_names).not_to be_empty
        end

        it "notifies the user of the success" do
          perform_enqueued_jobs

          mail = ActionMailer::Base.deliveries
                                   .find { |m| m.message_id.start_with? "op.project-#{subject.id}" }

          expect(mail).to be_present
          expect(mail.subject).to eq "Created project #{subject.name}"
          expect(mail.to).to eq [user.mail]
        end
      end

      describe 'user without add_subprojects permission in parent and when explicitly setting that parent' do
        let(:params) { { name: 'Copy', identifier: 'copy', parent_id: project.id } }

        include_context 'copy project' do
          let(:project_to_copy) { subproject }
        end

        it 'does not copy the project' do
          expect(subject).to be_nil
        end

        it "notifies the user of that parent not being allowed" do
          perform_enqueued_jobs

          mail = ActionMailer::Base.deliveries.first
          expect(mail).to be_present
          expect(mail.subject).to eq I18n.t('copy_project.failed', source_project_name: subproject.name)
          expect(mail.to).to eq [user.mail]
        end
      end

      describe 'user with add_subprojects permission in parent' do
        let(:role_add_subproject) { create(:project_role, permissions: [:add_subprojects]) }
        let(:member_add_subproject) do
          create(:member,
                 user:,
                 project:,
                 roles: [role_add_subproject])
        end

        before do
          member_add_subproject
        end

        include_context 'copy project' do
          let(:project_to_copy) { subproject }
        end

        it 'copies the project' do
          expect(subject).not_to be_nil
          expect(subject.parent).to eql(project)

          expect(subproject.reload.enabled_module_names).not_to be_empty
        end

        it "notifies the user of the success" do
          perform_enqueued_jobs

          mail = ActionMailer::Base.deliveries
                                   .find { |m| m.message_id.start_with? "op.project-#{subject.id}" }

          expect(mail).to be_present
          expect(mail.subject).to eq "Created project #{subject.name}"
          expect(mail.to).to eq [user.mail]
        end
      end
    end
  end
end
