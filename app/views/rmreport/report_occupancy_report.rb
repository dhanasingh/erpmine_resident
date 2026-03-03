module ReportOccupancyReport
  include WkreportHelper

  def calcReportData(user_id, group_id, projId, from, to, location_id = nil)
    as_on_date = [to.present? ? to.to_date : Date.current, Date.current].min
    prev_month_end = as_on_date.prev_month.end_of_month

    capacity = capacity_by_facility(projId, location_id)
    prev_month_occupancy = occupancy_by_facility(prev_month_end, projId, location_id)
    current_occupancy = occupancy_by_facility(as_on_date, projId, location_id)

    rows = capacity.map do |facility_key, total_capacity|
      facility_id, facility_name = facility_key
      previous_occ = prev_month_occupancy[facility_id].to_i
      current_occ = current_occupancy[facility_id].to_i
      percent_occ = total_capacity.to_i > 0 ? ((current_occ.to_f / total_capacity.to_f) * 100.0).round(1) : 0.0

      {
        facility: facility_name,
        total_capacity: total_capacity.to_i,
        prev_month_occ: previous_occ,
        current_occ: current_occ,
        percent_occ: percent_occ,
        vacant: (total_capacity.to_i - current_occ)
      }
    end

    total_cap = rows.sum { |r| r[:total_capacity] }
    total_prev = rows.sum { |r| r[:prev_month_occ] }
    total_curr = rows.sum { |r| r[:current_occ] }
    total_pct  = total_cap > 0 ? ((total_curr.to_f / total_cap.to_f) * 100.0).round(1) : 0.0
    total_vac  = rows.sum { |r| r[:vacant] }

    {
      as_on_date: as_on_date,
      prev_month_label: prev_month_end.strftime('%b %Y'),
      rows: rows,
      totals: {
        facility: l(:label_total),
        total_capacity: total_cap,
        prev_month_occ: total_prev,
        current_occ: total_curr,
        percent_occ: total_pct,
        vacant: total_vac
      }
    }
  end

  def getExportData(user_id, group_id, projId, from, to, location_id = nil)
    report_data = calcReportData(user_id, group_id, projId, from, to, location_id)
    export_data = {headers: {}, data: []}

    prev_month_header = "#{l(:label_prev_month_occ)} (#{report_data[:prev_month_label]})"

    export_data[:headers] = {
      facility: l(:label_facility),
      total_capacity: l(:label_total_capacity),
      prev_month_occ: prev_month_header,
      current_occ: l(:label_current_occ),
      percent_occ: l(:label_percent_occ),
      vacant: l(:label_vacant)
    }

    report_data[:rows].each do |row|
      export_data[:data] << {
        facility: row[:facility],
        total_capacity: row[:total_capacity],
        prev_month_occ: row[:prev_month_occ],
        current_occ: row[:current_occ],
        percent_occ: format('%.1f%%', row[:percent_occ]),
        vacant: row[:vacant]
      }
    end

    t = report_data[:totals]
    export_data[:totals] = {
      facility: t[:facility],
      total_capacity: t[:total_capacity],
      prev_month_occ: t[:prev_month_occ],
      current_occ: t[:current_occ],
      percent_occ: format('%.1f%%', t[:percent_occ]),
      vacant: t[:vacant]
    }

    export_data[:as_on_date]      = report_data[:as_on_date]
    export_data[:prev_month_label] = report_data[:prev_month_label]
    export_data[:customize]        = true
    export_data
  end

  def csv_export(data)
    require 'csv'

    CSV.generate do |csv|
      csv << [l(:report_occupancy_report)]
      csv << [data[:as_on_date].strftime('%B %Y')]
      csv << data[:headers].values

      data[:data].each do |row|
        csv << data[:headers].keys.map { |key| row[key] }
      end

      if data[:data].any? && data[:totals].present?
        csv << data[:headers].keys.map { |key| data[:totals][key] }
      end
    end
  end

  def pdf_export(headers:, data:, as_on_date:, totals: nil, prev_month_label: nil, location: nil, logo: nil, from: nil, to: nil, **)
    pdf = ITCPDF.new(current_language, 'L')
    pdf.add_page

    row_height = 7
    page_width = pdf.get_page_width
    left_margin = pdf.get_original_margins['left']
    right_margin = pdf.get_original_margins['right']
    table_width = page_width - right_margin - left_margin
    col_widths = [table_width * 0.42, table_width * 0.10, table_width * 0.20, table_width * 0.13, table_width * 0.075, table_width * 0.075]

    pdf.SetFontStyle('B', 14)
    pdf.RDMMultiCell(table_width, 6, l(:report_occupancy_report), 0, 'C')
    pdf.SetFontStyle('', 10)
    pdf.RDMMultiCell(table_width, 5, as_on_date.strftime('%B %Y'), 0, 'C')

    if logo.present?
      pdf.Image(logo.diskfile.to_s, page_width - 50, 10, 30, 25)
      pdf.set_y([pdf.get_y, 38].max)
    end

    pdf.ln(6)
    pdf.SetFontStyle('B', 8)
    pdf.set_fill_color(230, 230, 230)
    headers.each_value.each_with_index do |value, i|
      pdf.RDMCell(col_widths[i], row_height, value.to_s, 1, 0, 'C', 1)
    end
    pdf.ln

    pdf.SetFontStyle('', 8)
    pdf.set_fill_color(255, 255, 255)
    data.each do |row|
      headers.each_key.each_with_index do |key, i|
        align = key == :facility ? 'L' : 'C'
        pdf.RDMCell(col_widths[i], row_height, row[key].to_s, 1, 0, align, 0)
      end
      pdf.ln
    end

    if totals.present?
      pdf.SetFontStyle('B', 8)
      pdf.set_fill_color(230, 230, 230)
      headers.each_key.each_with_index do |key, i|
        align = key == :facility ? 'R' : 'C'
        pdf.RDMCell(col_widths[i], row_height, totals[key].to_s, 1, 0, align, 1)
      end
      pdf.ln
    end

    pdf.Output
  end

  private

  def capacity_by_facility(projId, location_id)
    entries = WkInventoryItem
      .joins("INNER JOIN wk_inventory_items apartment ON apartment.id = wk_inventory_items.parent_id" + get_comp_cond('apartment'))
      .joins("LEFT JOIN wk_locations loc ON loc.id = apartment.location_id" + get_comp_cond('loc'))
      .where("wk_inventory_items.product_type = 'RA' AND wk_inventory_items.parent_id IS NOT NULL" + get_comp_cond('wk_inventory_items'))
      .where("loc.id IS NOT NULL")

    if projId.present? && projId.to_s != '0'
      entries = entries.where('COALESCE(wk_inventory_items.project_id, apartment.project_id) = ?', projId.to_i)
    end

    if location_id.present? && location_id.to_s != '0'
      entries = entries.where('apartment.location_id = ?', location_id.to_i)
    end

    entries
      .group('loc.id', 'loc.name')
      .order('loc.name')
      .count('DISTINCT wk_inventory_items.id')
  end

  def occupancy_by_facility(as_on_date, projId, location_id)
    entries = RmResident
      .joins("INNER JOIN wk_inventory_items bed ON bed.id = rm_residents.bed_id" + get_comp_cond('bed'))
      .joins("INNER JOIN wk_inventory_items apartment ON apartment.id = bed.parent_id" + get_comp_cond('apartment'))
      .joins("LEFT JOIN wk_locations loc ON loc.id = apartment.location_id" + get_comp_cond('loc'))
      .where("rm_residents.bed_id IS NOT NULL" + get_comp_cond('rm_residents'))
      .where('rm_residents.move_in_date <= ? AND (rm_residents.move_out_date IS NULL OR rm_residents.move_out_date > ?)', as_on_date.end_of_day, as_on_date.end_of_day)
      .where('loc.id IS NOT NULL')

    if projId.present? && projId.to_s != '0'
      entries = entries.where('COALESCE(bed.project_id, apartment.project_id) = ?', projId.to_i)
    end

    if location_id.present? && location_id.to_s != '0'
      entries = entries.where('apartment.location_id = ?', location_id.to_i)
    end

    entries.group('loc.id').count('DISTINCT rm_residents.bed_id')
  end
end
