module Testing
  module Nczi
    class UpdateMoms < ApplicationJob
      include NcziApi
      include Overridable

      def perform
        ActiveRecord::Base.transaction do
          fetch_moms!
          update_regions!
          update_counties!
          update_moms!
          disable_missing_moms!

          logger.info "Done updating NCZI moms. Currently we have #{NcziMom.enabled.count} enabled NCZI moms"
        end
      end

      private

      attr_reader :moms

      def fetch_moms!
        @moms = fetch_nczi_data.map do |mom|
          mom
            .merge(
              external_id: mom[:id],
              external_details: mom,
              reservations_url: 'https://www.old.korona.gov.sk/covid-19-patient-form.php',
              updated_at: Time.zone.now,
              enabled: true,
            )
            .except(:id)
        end
      end

      def update_regions!
        regions = moms.map do |mom|
          next unless mom[:region_id].present?

          {
            external_id: mom[:region_id],
            name: mom[:region_name],
          }
        end.compact.uniq

        return if regions.empty?

        Region.upsert_all(regions, unique_by: :external_id)
      end

      def update_counties!
        counties = moms.map do |mom|
          next unless mom[:county_id].present?

          region = region_by_external_id(mom[:region_id])

          next if mom[:county_name].blank?

          {
            external_id: mom[:county_id],
            region_id: region&.id,
            name: mom[:county_name],
          }
        end.compact.uniq

        return if counties.empty?

        County.upsert_all(counties, unique_by: :external_id)
      end

      def update_moms!
        updated_moms = moms.map do |mom|
          region = region_by_external_id(mom[:region_id])
          county = county_by_external_id(mom[:county_id])

          mom[:region_id] = region&.id
          mom[:county_id] = county&.id
          mom[:type] = 'NcziMom'

          mom = override_attributes(mom, all_overrides)

          mom.except(:region_name, :county_name)
        end

        return if updated_moms.empty?

        Mom.upsert_all(updated_moms, unique_by: :external_id)
      end

      def disable_missing_moms!
        NcziMom
          .enabled
          .where.not(external_id: moms.pluck(:external_id))
          .update_all(enabled: false).tap do |num_disabled_moms|
          logger.info "Disabled #{num_disabled_moms} NCZI moms"
        end
      end

      def all_overrides
        @all_overrides ||= PlaceOverride.all
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
        nczi_get_payload("#{base_url}/get_all_drivein_times")
          .map do |record|
          record.except('calendar_data')
        end
          .map(&:symbolize_keys)
      end
    end
  end
end