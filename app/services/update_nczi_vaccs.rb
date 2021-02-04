class UpdateNcziVaccs < ApplicationService
  include NcziClient

  attr_reader :data

  def initialize(data: nil)
    @data = data
  end

  def perform
    logger.info "Updating NCZI vaccs"

    ActiveRecord::Base.transaction do
      fetch_vaccs!
      update_regions!
      update_counties!
      update_vaccs!
      disable_missing_vaccs!
    end
  end

  private

  attr_reader :vaccs

  def fetch_vaccs!
    @vaccs = fetch_nczi_data.map do |vacc|
      vacc
        .merge(
          enabled: true,
          external_id: vacc[:id],
          reservations_url: 'https://www.old.korona.gov.sk/covid-19-vaccination-form.php',
          updated_at: Time.zone.now,
        )
        .except(:id)
    end
  end

  def update_regions!
    regions = vaccs.map do |vacc|
      next unless vacc[:region_id].present?

      {
        external_id: vacc[:region_id],
        name: vacc[:region_name],
      }
    end.compact.uniq

    Region.upsert_all(regions, unique_by: :external_id)
  end

  def update_counties!
    counties = vaccs.map do |vacc|
      next unless vacc[:county_id].present?

      region = region_by_external_id(vacc[:region_id])

      {
        external_id: vacc[:county_id],
        region_id: region&.id,
        name: vacc[:county_name],
      }
    end.compact.uniq

    County.upsert_all(counties, unique_by: :external_id)
  end

  def update_vaccs!
    updated_vaccs = vaccs.map do |vacc|
      region = region_by_external_id(vacc[:region_id])
      county = county_by_external_id(vacc[:county_id])

      vacc[:region_id] = region&.id
      vacc[:county_id] = county&.id

      vacc.except(:region_name, :county_name)
    end

    Vacc.upsert_all(updated_vaccs, unique_by: :external_id)
  end

  def disable_missing_vaccs!
    NcziVacc
      .enabled
      .where.not(external_id: vaccs.pluck(:external_id))
      .update_all(enabled: false).tap do |num_disabled_moms|
      logger.info "Disabled #{num_disabled_moms} NCZI vaccs"
    end
  end

  def all_regions
    @all_regions ||= Region.all
  end

  def region_by_external_id(external_id)
    return if external_id.nil?

    all_regions.find do |region|
      region.external_id == external_id
    end
  end

  def all_counties
    @all_counties ||= County.all
  end

  def county_by_external_id(external_id)
    return if external_id.nil?

    all_counties.find do |county|
      county.external_id == external_id
    end
  end

  def fetch_nczi_data
    if data.present?
      data
    else
      response = if Rails.application.config.x.nczi.use_proxy
                   nczi_client.get('https://data.korona.gov.sk/ncziapi/get_driveins_vacc')
                 else
                   nczi_client.get('https://mojeezdravie.nczisk.sk/api/v1/web/get_driveins_vacc')
                 end
      response.body.fetch('payload', [])
    end
      .map(&:symbolize_keys)
  end
end