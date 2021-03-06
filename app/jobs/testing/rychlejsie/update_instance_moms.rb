module Testing
  module Rychlejsie
    class UpdateInstanceMoms < ApplicationJob
      include RychlejsieApi
      include Overridable

      attr_reader :base_url
      attr_reader :city
      attr_reader :region

      def perform(base_url:, city:, region:)
        @base_url = base_url
        @city = city
        @region = region

        logger.tagged(base_url) do
          ActiveRecord::Base.transaction do
            logger.info "Updating Rychlejsie Moms from #{base_url} #{city} #{region.name}"

            fetch_moms!

            update_counties!
            update_moms!
            disable_missing_moms!

            logger.info "Done updating Rychlejsie Moms. Currently we have #{RychlejsieMom.enabled.count} enabled Rychlejsie moms"
          end
        end
      end

      private

      attr_reader :moms

      def fetch_moms!
        @moms = fetch_data.map do |mom|
          address = mom[:address]
          _, street_name, postal_code, county_name = address.match(/(.+?),\ ([0-9 ]{5,6})\ (.*)/).to_a

          {
            enabled: true,
            title: mom[:name],
            longitude: mom[:lng],
            latitude: mom[:lat],
            city: city,
            street_name: street_name,
            street_number: nil,
            postal_code: postal_code,
            county_name: county_name,
            updated_at: Time.zone.now,
            reservations_url: "#{base_url}/#/place/%{external_id}",
            supports_reservation: mom[:hasReservationSystem],
            external_id: mom[:id],
            external_endpoint: base_url,
            external_details: mom,
          }
        end
      end

      def update_counties!
        counties = moms.map do |mom|
          next if mom[:county_name].blank?
          {
            external_id: mom[:county_name],
            region_id: region.id,
            name: mom[:county_name],
          }
        end.compact.uniq

        return if counties.empty?

        County.upsert_all(counties, unique_by: :external_id)
      end

      def update_moms!
        updated_moms = moms.map do |mom|
          county = county_by_external_id(mom[:county_name])

          mom[:region_id] = region.id
          mom[:county_id] = county&.id
          mom[:type] = 'RychlejsieMom'

          mom = override_attributes(mom, all_overrides)

          mom.except(:region_name, :county_name)
        end

        return if updated_moms.empty?

        Mom.upsert_all(updated_moms, unique_by: :external_id)
      end

      def disable_missing_moms!
        RychlejsieMom
          .enabled
          .where(external_endpoint: base_url)
          .where.not(external_id: moms.pluck(:external_id))
          .update_all(enabled: false).tap do |num_disabled_moms|
          logger.info "Disabled #{num_disabled_moms} Rychlejsie.sk moms"
        end
      end

      def all_counties
        @all_counties ||= County.all
      end

      def all_overrides
        @all_overrides ||= PlaceOverride.all
      end

      def county_by_external_id(external_id)
        return if external_id.nil?

        all_counties.find do |county|
          county.external_id == external_id
        end
      end

      def fetch_data
        rychlejsie_client
          .get("#{base_url}/api/Place/ListFiltered?availability=all&category=all")
          .body
          .map(&:last)
          .map(&:symbolize_keys)
      end
    end
  end
end