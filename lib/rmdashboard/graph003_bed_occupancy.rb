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
      to = (param[:to] || Date.today).end_of_month
      from = param[:from] ? param[:from].beginning_of_month : (to - 11.months).beginning_of_month
      location_id = param[:location_id]

      header = {
        month: l(:label_month, default: "Month"),
        occupied: l(:label_occupied, default: "Occupied") + " " + l(:label_beds, default: "beds"),
        total: l(:label_total, default: "Total") + " " + l(:label_beds, default: "beds")
      }

      data = []

      # Build list of months
      current_month = from
      while current_month <= to
        month_end = current_month.end_of_month.end_of_day

        # Count occupied beds scoped to location (apartment-location scope: picked-zone ∩ accessible locations)
        bed_occupied_query = RmResident
          .where("rm_residents.bed_id IS NOT NULL")
          .where("rm_residents.move_in_date <= ? AND (rm_residents.move_out_date IS NULL OR rm_residents.move_out_date > ?)", month_end, month_end)
        bed_occupied_query = RmResident.in_apartment_location_scope(bed_occupied_query, location_id)
        bed_occupied_count = bed_occupied_query.count('DISTINCT rm_residents.bed_id')

        # Residents moved into an apartment directly (no bed assigned) also occupy capacity
        apt_occupied_query = RmResident
          .where("rm_residents.bed_id IS NULL AND rm_residents.apartment_id IS NOT NULL")
          .where("rm_residents.move_in_date <= ? AND (rm_residents.move_out_date IS NULL OR rm_residents.move_out_date > ?)", month_end, month_end)
        apt_occupied_query = RmResident.in_apartment_location_scope(apt_occupied_query, location_id)
        apt_occupied_count = apt_occupied_query.count('DISTINCT rm_residents.apartment_id')

        occupied_count = bed_occupied_count + apt_occupied_count

        loc_ids = location_id.present? ? WkLocation.report_location_ids(location_id) : nil

        # Count total beds scoped to location (product_type 'RA' with parent_id)
        bed_total_query = WkInventoryItem
          .joins("INNER JOIN wk_inventory_items apartment ON apartment.id = wk_inventory_items.parent_id")
          .where(product_type: 'RA')
          .where("wk_inventory_items.parent_id IS NOT NULL")
          .where("wk_inventory_items.created_at <= ?", month_end)
        bed_total_query = bed_total_query.where("apartment.location_id IN (?)", (loc_ids.presence || [-1])) unless loc_ids.nil?
        bed_total_count = bed_total_query.count('DISTINCT wk_inventory_items.id')

        # Apartments without any child bed also count as occupiable capacity
        apt_total_query = WkInventoryItem
          .where(product_type: 'RA')
          .where("wk_inventory_items.parent_id IS NULL")
          .where("wk_inventory_items.created_at <= ?", month_end)
          .where("NOT EXISTS (SELECT 1 FROM wk_inventory_items child WHERE child.parent_id = wk_inventory_items.id)")
        apt_total_query = apt_total_query.where("wk_inventory_items.location_id IN (?)", (loc_ids.presence || [-1])) unless loc_ids.nil?
        apt_total_count = apt_total_query.count('DISTINCT wk_inventory_items.id')

        total_count = bed_total_count + apt_total_count

        data << {
          month: current_month.strftime("%b %Y"),
          occupied: occupied_count,
          total: total_count
        }

        current_month = current_month.next_month
      end

      return { header: header, data: data }
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