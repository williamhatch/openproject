# Register "Cron-like jobs"

OpenProject::Application.configure do |application|
  application.config.good_job.cron.merge!(
    {
      'Cron::ClearOldSessionsJob': {
        cron: '15 1 * * *', # runs at 1:15 nightly
        class: 'Cron::ClearOldSessionsJob'
      },
      'Cron::ClearTmpCacheJob': {
        cron: '45 2 * * 7', # runs at 02:45 sundays
        class: 'Cron::ClearTmpCacheJob'
      },
      'Cron::ClearUploadedFilesJob': {
        cron: '0 23 * * 5', # runs 23:00 fridays
        class: 'Cron::ClearUploadedFilesJob'
      },
      'OAuth::CleanupJob': {
        cron: '52 1 * * *',
        class: 'OAuth::CleanupJob'
      },
      'PaperTrailAudits::CleanupJob': {
        cron: '3 4 * * 6',
        class: 'PaperTrailAudits::CleanupJob'
      },
      'Attachments::CleanupUncontaineredJob': {
        cron: '03 22 * * *', # runs at 10:03 pm
        class: 'Attachments::CleanupUncontaineredJob'
      },
      'Notifications::ScheduleDateAlertsNotificationsJob': {
        cron: '*/15 * * * *', # runs every 15th minute
        class: 'Notifications::ScheduleDateAlertsNotificationsJob'
      },
      'Notifications::ScheduleReminderMailsJob': {
        cron: '*/15 * * * *', # runs every 15th minute
        class: 'Notifications::ScheduleReminderMailsJob'
      }
    }
  )
end
