require 'clockwork'
require './config/boot'
require './config/environment'

Thread.report_on_exception = true

module Clockwork
  every(Rails.application.config.x.testing.update_interval.minutes, 'update_all_test_date_snapshots') do
    SkCovidTesting::Application.load_tasks

    UpdateNcziMoms.new.perform
    RychlejsieMom.instances.map do |config|
      UpdateRychlejsieMoms.new(config).perform
    end
    UpdateAllTestingSnapshots.new(rate_limit: Rails.application.config.x.testing.rate_limit).perform
  end

  every(Rails.application.config.x.vaccination.update_interval.minutes, 'update_all_vaccination_date_snapshots') do
    SkCovidTesting::Application.load_tasks

    update_result = UpdateAllNcziVaccinationData.new.perform
    latest_snapshots = update_result.flatten
    NotifyVaccinationSubscriptions.new(latest_snapshots: latest_snapshots).perform
  end

  # every(
  #   [
  #     Rails.application.config.x.testing.update_interval.minutes,
  #     Rails.application.config.x.vaccination.update_interval.minutes,
  #   ].max,
  #   'update_all'
  # ) do
  #   SkCovidTesting::Application.load_tasks
  #
  #   update_result = UpdateAllNcziVaccinationData.new.perform
  #   latest_snapshots = update_result.flatten
  #   NotifyVaccinationSubscriptions.new(latest_snapshots: latest_snapshots).perform
  #
  #   # UpdateNcziMoms.new.perform
  #   # RychlejsieMom.instances.map do |config|
  #   #   UpdateRychlejsieMoms.new(config).perform
  #   # end
  #   #
  #   # UpdateAllTestingSnapshots.new(rate_limit: Rails.application.config.x.testing.rate_limit).perform
  # end

  error_handler do |error|
    Rails.logger.error(error)
  end
end

