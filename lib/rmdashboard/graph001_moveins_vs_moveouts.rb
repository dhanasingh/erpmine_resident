module Rmdashboard
  module Graph001MoveinsVsMoveouts
    include RmresidentHelper

    def chart_data(param={})
      to = param[:to].end_of_month
      from = to - 12.months + 1.days
      location_id = param[:location_id]
      data = {
        graphName: l(:label_moveins_vs_moveouts), chart_type: "bar", xTitle: l(:label_months), yTitle: l(:label_resident),
        legentTitle1: l(:label_move_ins), legentTitle2: l(:label_move_outs)
      }
      data[:fields] = (Array.new(12){|indx| month_name(((to.month - 1 - indx) % 12) + 1).first(3)}).reverse

      # Move-Ins grouped by month
      moveIns = RmResident.where(
        move_in_date: from.beginning_of_day..to.end_of_day
      )

      if location_id.present?
        apartment_ids = WkInventoryItem.where(
          location_id: location_id
        ).pluck(:id)

        moveIns = moveIns.where(
          apartment_id: apartment_ids
        )
      end

      moveIns = moveIns
        .group(getDatePart("rm_residents.move_in_date", "month"))
        .select(
          getDatePart("rm_residents.move_in_date", "month", "month_val") +
          ", count(*) as move_count"
        )

      moveInData = Array.new(12, 0)

      moveIns.each do |m|
        index = ((m.month_val.to_i - from.month) % 12)
        moveInData[index] = m.move_count
      end

      data[:data1] = moveInData

      # Move-Outs grouped by month
      moveOuts = RmResident.where.not(move_out_date: nil)
        .where(move_out_date: from.beginning_of_day..to.end_of_day)

      if location_id.present?
        apartment_ids = WkInventoryItem.where(
          location_id: location_id
        ).pluck(:id)

        moveOuts = moveOuts.where(
          apartment_id: apartment_ids
        )
      end

      moveOuts = moveOuts
        .group(getDatePart("rm_residents.move_out_date", "month"))
        .select(
          getDatePart("rm_residents.move_out_date", "month", "month_val") +
          ", count(*) as move_count"
        )

      moveOutData = Array.new(12, 0)

      moveOuts.each do |m|
        index = ((m.month_val.to_i - from.month) % 12)
        moveOutData[index] = m.move_count
      end

      data[:data2] = moveOutData

      return data
    end

    def get_detail_report(param={})
      to = param[:to].end_of_month
      from = to - 12.months + 1.days
      entries = RmResident.where(move_in_date: from.beginning_of_day..to.end_of_day)
        .order("move_in_date DESC")
      header = {name: l(:label_resident), move_in: l(:field_move_in_date), move_out: l(:field_move_out_date), status: l(:field_status)}
      data = entries.map{|e| {
        name: e&.name,
        move_in: e&.move_in_date&.to_date,
        move_out: e&.move_out_date&.to_date,
        status: e.move_out_date.present? ? l(:label_move_out) : l(:button_move_in)
      }}
      return {header: header, data: data}
    end
  end
end
