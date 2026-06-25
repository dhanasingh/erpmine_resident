module Rmdashboard
  module Graph003BedOccupancy
    include RmresidentHelper
    include WkassetHelper

    def chart_data(param={})
      to = param[:to].end_of_month
      from = (to - 11.months).beginning_of_month
      location_id = param[:location_id]

      data = {
        graphName: l(:label_bed_occupancy, default: "Bed Occupancy"),
        chart_type: "line",
        xTitle: l(:label_months),
        yTitle: l(:label_occupied),

        legentTitle1: "All Locations",
        legentTitle2: "Selected Location"
      }

      unless location_id.present?
        data.delete(:legentTitle2)
      end

      data[:fields] = (0..11).map do |i|
        date = from + i.months
        month_name(date.month).first(3)
      end

      all_location_data = []
      selected_location_data = []

      today = Date.today

      (0..11).each do |i|

        as_on_date = [(from + i.months).end_of_month, today].min

        all_location_data << total_occupied(as_on_date)

        if location_id.present?
          selected_location_data << total_occupied(
            as_on_date,
            location_id
          )
        end
      end

      data[:data1] = all_location_data
      data[:data2] = selected_location_data if location_id.present?

      return data
    end

    def get_detail_report(param={})
      to = param[:to].end_of_month
      from = (to - 11.months).beginning_of_month
      month_start = from.beginning_of_day
      month_end = to.end_of_day

      move_ins = RmResident
        .where("move_in_date >= ? AND move_in_date <= ?", month_start, month_end)
        .includes(:apartment, :bed)
      # Apartment-location scope (honours picked zone + accessible locations).
      move_ins = RmResident.in_apartment_location_scope(move_ins, param[:location_id])

      header = {
        name: l(:label_resident),
        apartment_name: l(:label_apartment),
        bedname: l(:label_bed),
        move_in: l(:field_move_in_date)
      }

      data = move_ins.map do |r|
        {
          name: r.name,
          apartment_name: r.apartment&.assetName || '',
          bedname: r.bed&.assetName || '',
          move_in: r.move_in_date&.to_date
        }
      end

      return {header: header, data: data}
    end

    private

    def total_occupied(as_on_date, location_id=nil)

      month_start = as_on_date.beginning_of_month.beginning_of_day
      month_end = as_on_date.end_of_month.end_of_day

      entries = RmResident.where(
        "move_in_date >= ? AND move_in_date <= ?",
        month_start,
        month_end
      )

      # Apartment-location scope: picked-zone subtree ∩ the user's accessible
      # locations. When no location is picked this restricts the "All Locations"
      # series to the user's accessible scope (admins => unrestricted).
      entries = RmResident.in_apartment_location_scope(entries, location_id)

      entries.count
    end

  end
end