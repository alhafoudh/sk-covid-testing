ActiveAdmin.register Mom do
  menu priority: 5

  config.sort_order = ''

  action_item only: :index do
    link_to 'Update testing places', update_moms_admin_moms_path, method: :post
  end

  collection_action :update_moms, method: :post do
    Testing::UpdateMoms.perform_now
  end

  actions :index, :show

  scope :all
  scope :enabled
  scope :other

  filter :region
  filter :county
  filter :enabled
  filter :type
  filter :title
  filter :external_id
  filter :city
  filter :street_name
  filter :postal_code
  filter :supports_reservation

  index do
    id_column
    column :region
    column :county
    column :enabled
    column :type
    column :title
    column :external_id
    column :city
    column :address_full
    column :supports_reservation
    actions
  end

  filter :enabled
  filter :region
  filter :county
  filter :title
  filter :external_id

  controller do
    def scoped_collection
      end_of_association_chain
        .left_joins(
          :region,
          :county
        )
        .includes(
          :region,
          :county,
        )
        .order('regions.name ASC, counties.name ASC, moms.title ASC')
    end

    before_action :update_scopes, only: :index

    def update_scopes
      resource = active_admin_config

      Region
        .order(name: :asc)
        .map do |region|
        next if resource.scopes.any? { |scope| scope.name == region.name }
        resource.scopes << (ActiveAdmin::Scope.new region.name do |places|
          places.where(region_id: region.id)
        end)
      end
    end
  end
end
