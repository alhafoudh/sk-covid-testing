require 'rails_helper'

describe ApplyOverride do
  let!(:record) do
    create(:nczi_mom,
      title: "AG Poliklinika Karlova Ves - vek od 6 rokov (1)",
      longitude: 17.06124286,
      latitude: 48.15410566,
      city: "Bratislava",
      street_name: "Líščie údolie",
      street_number: "57 - interér",
      postal_code: nil,
      region_id: nil,
      county_id: nil,
      reservations_url: "https://www.old.korona.gov.sk/covid-19-patient-form.php",
      external_id: "289",
      external_endpoint: nil,
      supports_reservation: true,
      enabled: false
    )
  end

  subject(:service) do
    ApplyOverride
      .new(
        record: record,
        replacements: replacements,
      )
      .perform
  end

  context 'empty replacements' do
    let(:replacements) do
      []
    end

    it 'should do nothing' do
      expect(record.changed?).to eq false
      service
      expect(record.changed?).to eq false
    end
  end

  context 'more separate replacements' do
    let(:replacements) do
      [
        { title: 'Foo bar' },
        { street_name: 'Bar baz' },
      ]
    end

    it 'should replace title' do
      expect(record.changed?).to eq false
      service
      expect(record.changed?).to eq true

      expect(record.title).to eq 'Foo bar'
      expect(record.street_name).to eq 'Bar baz'
    end
  end

  context 'more combined replacements' do
    let(:replacements) do
      [
        { title: 'Foo bar', street_name: 'Bar baz' },
      ]
    end

    it 'should replace title' do
      expect(record.changed?).to eq false
      service
      expect(record.changed?).to eq true

      expect(record.title).to eq 'Foo bar'
      expect(record.street_name).to eq 'Bar baz'
    end
  end

  context 'replacements with ERB' do
    let(:replacements) do
      [
        { title: 'Foo <%= record.street_name %> Bar' },
      ]
    end

    it 'should replace title with ERB template' do
      service
      expect(record.title).to eq 'Foo Líščie údolie Bar'
    end
  end

  context 'replacements with nil value' do
    let(:replacements) do
      [
        { title: nil },
      ]
    end

    it 'should replace title with ERB template' do
      service
      expect(record.title).to be_nil
    end
  end
end
