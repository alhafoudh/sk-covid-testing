class UpdateNcziVaccinationSnapshots < VaccinationSnapshotsBase
  include NcziClient

  attr_reader :vacc

  def initialize(vacc:)
    @vacc = vacc
  end

  def perform
    logger.info "Updating NCZI vaccination date snapshots for vacc #{vacc.inspect}"

    ActiveRecord::Base.transaction do
      snapshots = fetch_snapshots
      created_snapshots = create_snapshots!(snapshots)
      latest_snapshots = update_latest_snapshots!(created_snapshots)
      disable_latest_snapshots!(snapshots)

      logger.info "Done updating NCZI vaccination date snapshots. Currently we have #{vacc.latest_snapshots.enabled.count} enabled latest snapshots."

      latest_snapshots
    end
  end

  private

  def fetch_snapshots
    data = fetch_raw_snapshots
    plan_date_statuses = data.fetch('payload', [])

    plan_date_statuses.map do |plan_date_status|
      parsed_date = Date.parse(plan_date_status['c_date'])
      plan_date = plan_dates.find do |plan_date|
        plan_date.date == parsed_date
      end

      unless plan_date.present?
        plan_date = VaccinationDate.create!(
          date: parsed_date,
        )
      end

      VaccinationDateSnapshot.new(
        plan_date: plan_date,
        vacc_id: vacc.id,
        is_closed: plan_date_status['is_closed'] == '1',
        free_capacity: plan_date_status.fetch('free_capacity', 0).to_i,
      )
    end
  end

  def plan_dates
    @plan_dates ||= VaccinationDate.all.to_a
  end

  def fetch_raw_snapshots
    response = nczi_client.post('https://mojeezdravie.nczisk.sk/api/v1/web/validate_drivein_times_vacc', { drivein_id: vacc.external_id.to_s })
    response.body
  end
end