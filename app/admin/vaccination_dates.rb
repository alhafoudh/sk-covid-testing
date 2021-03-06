ActiveAdmin.register VaccinationDate do
  menu priority: 6

  config.sort_order = 'date_asc'

  actions :index

  filter :date

  index do
    id_column
    column :date
  end
end
