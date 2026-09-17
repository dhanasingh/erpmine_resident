# ERPmine Resident
# Copyright (C) 2026-  Adhi software pvt ltd
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

# This plugin's REST endpoints, contributed to the redmine_mcp tool catalogue
# through the :redmine_mcp_register_tools hook. redmine_mcp discovers this class
# as a hook listener the moment init.rb requires the file — it needs no entry of
# its own — and the rows are inert when redmine_mcp is not installed.
#
# Each row is [tool_name, http_method, path, description] — what
# RedmineMcp::RestEndpoint expects. Add a row to expose another endpoint. Name
# tools after the business object, not the rm* controller.
#
# Only actions erpmine_resident marks with `accept_api_auth` can be listed —
# anything else answers 401/406. `accept_api_auth` is a class_attribute, so a
# subclass that redeclares it REPLACES the parent's list: rmevaluation accepts
# only :index even though WksurveyController accepts more, while
# rmperformservice declares none and so inherits WktimeController's whole list.
# Rails view lookup walks the same chain, which is why rmperformservice renders
# wktime/* templates.
#
# ORDER: the plugin's own menu order (ResidentHook#external_erpmine_menus) —
# Apartments, Residents, Perform Service, Incidents, Evaluations, Dashboard —
# then the lookups, which have no menu entry of their own.
#
# PATHS: every route in erpmine_resident is an explicit `get 'rmx/action'`, so
# list paths are /rmx/index.json, never /rmx.json.
#
# GOTCHAS:
#   * list_service_activities has no `.json` suffix on purpose: the action
#     answers JSON only when no format is given, so `.json` returns plain text.
#   * move_out_resident and transfer_resident take the date in "move_in_date" —
#     the controller reuses the move-in form's key for the move-out date.
#   * rmperformservice#index only redirects, so there is no list tool for
#     service sheets; get_service_sheet loads one week directly.
#
# WRITES: POST to a save-style action, never PUT, and no /:id in the path. The
# body is a FLAT object of top-level params except where noted. One action both
# creates and updates — omit the record's id to create — so create_*/update_*
# are two tools over one endpoint. Success returns an empty body or a bare id,
# failures 422.
#
# Deliberately absent: deletes (#destroy, #residentservicedestroy).
class ResidentMcpHook < Redmine::Hook::Listener
  ENDPOINTS = [
    # --- Apartments (rmapartment) ---------------------------------------
    ['list_apartments', :get, '/rmapartment/index.json',
     'List apartments and the beds inside them, with attribute, serial number, rate and location. query: location_id, availability (A available, U occupied), offset, limit. A row with a blank bed is the apartment itself.'],
    ['get_apartment', :get, '/rmapartment/edit.json',
     'Get one apartment or bed with its rate, location, attribute and the beds under it. query: inventory_item_id, or parentId to start a new bed under that apartment.'],
    ['create_apartment', :post, '/rmapartment/update.json',
     'Create an apartment, or a bed inside one. body {"product_id", "asset_name", "product_attribute_id", "serial_number", "location_id", "rate", "rate_per", "owner_type", "currency", "parent_id", "available_quantity", "is_loggable", "notes"}. parent_id is the apartment inventory_item_id for a bed; omit it for an apartment. available_quantity is required; without it nothing is created and the call still returns 200. Omit inventory_item_id to create. The response carries no id, so confirm with list_apartments.'],
    ['update_apartment', :post, '/rmapartment/update.json',
     'Update an apartment or bed. body {"inventory_item_id", "product_item_id", "asset_property_id", ...same fields as create_apartment}. Send product_id exactly as get_apartment returns it, or a duplicate product item is created. serial_number is only stored on create.'],

    # --- Residents (rmresident) -----------------------------------------
    ['list_residents', :get, '/rmresident/index.json',
     'List residents with their location, apartment, bed and move-in/move-out dates. query: moveinout_id (MI currently resident, MO moved out, blank for both), location_id, polymorphic_filter ("2" filter by contact, "3" by account), contact_id, account_id, period_type, period, from, to, offset, limit. The date range applies to the move-in date for MI and the move-out date for MO.'],
    ['get_resident', :get, '/rmresident/edit.json',
     'Get one resident with their contact or account fields, address, apartment, bed, current status and their services and amenities. query: rm_resident_id.'],
    ['create_resident', :post, '/rmresident/update.json',
     'Create the person or company behind a resident. body {"resident_type" ("WkCrmContact" or "WkAccount"), "salutation", "first_name", "last_name", "contact_title", "department", "description", "assigned_user_id", "relationship_id", "location_id", "related_to", "related_parent", "address": [["street", ""], ["city", ""]]}. For "WkAccount" send account fields instead: "account_name", "account_number", "account_category", "tax_number", "account_billing". The response is the new contact or account id — pass it to move_in_resident as resTypeID to make it a resident.'],
    ['update_resident', :post, '/rmresident/update.json',
     'Update a resident\'s contact or account fields. body {"resident_id" (the rm_resident id, which fixes the type), "contact_id" or "account_id", ...same fields as create_resident}. Call get_resident first and re-submit every field it returns — any field omitted is overwritten blank.'],
    ['move_in_resident', :post, '/rmresident/moveInResident.json',
     'Move a contact, account or lead into an apartment, creating the resident record. body {"resTypeID", "resType" ("WkCrmContact" or "WkAccount"), "model_name" (same value, to stamp the record as a resident), "move_in_date", "move_in_hr", "move_in_min", "apartment_idM", "bed_idM", "rateM"}. Send lead_id instead of resTypeID/resType to convert a lead. Take apartment_idM from list_location_apartments, bed_idM from list_apartment_beds (omit it when the apartment has no beds) and rateM from get_bed_rate.'],
    ['transfer_resident', :post, '/rmresident/residentTransfer.json',
     'Move an existing resident to another apartment or bed. body {"resident_id" (the rm_resident id being moved out), "resTypeID", "resType", "move_in_date" (the transfer date), "move_in_hr", "move_in_min", "apartment_idM", "bed_idM", "rateM"}. The old stay is closed the day before move_in_date and the services are carried over.'],
    ['move_out_resident', :post, '/rmresident/moveOut.json',
     'Move a resident out. body {"resident_id", "move_in_date" (the move-out date, despite the key), "move_in_hr", "move_in_min", "move_out_reason"}. The date cannot be before the move-in date. move_out_reason is an enumeration id of type MOR.'],
    ['create_resident_service', :post, '/rmresident/updateresidentservice.json',
     'Add a service or amenity to a resident. body {"residentService": {"rm_resident_id", "issue_id", "start_date", "end_date", "frequency", "no_of_occurrence"}}. Take issue_id from the resident_services or resident_amenities lists in get_resident. start_date cannot be before the resident\'s move-in date, and nothing can be added once they have moved out. Omit "id" to create.'],
    ['update_resident_service', :post, '/rmresident/updateresidentservice.json',
     'Update a resident\'s service or amenity. body {"residentService": {"id", ...same fields as create_resident_service}}. Take id from the services or amenities array in get_resident. end_date cannot be after the move-out date.'],

    # --- Perform Service (rmperformservice) -----------------------------
    ['get_service_sheet', :get, '/rmperformservice/edit.json',
     'Get one week of performed-service entries for a user, with their editable rows. query: user_id, startday (YYYY-MM-DD, the first day of the week). Only the resident-service tracker\'s issues appear; the project and activity are fixed by the resident plugin settings.'],
    ['create_service_entries', :post, '/rmperformservice/update.json',
     'Record services performed for residents. body {"user_id", "startday", "wktime_save": 1, "time_entries": [{"project": {"id"}, "issue": {"id"}, "activity": {"id"}, "spent_on", "hours", "comments"}]}. Take issue ids from search_service_issues and the activity id from list_service_activities. Omit each entry\'s "id" to create it.'],
    ['update_service_entries', :post, '/rmperformservice/update.json',
     'Update performed-service entries. Same body as create_service_entries, but each entry carries the "id" returned by get_service_sheet. Entries omitted from the array are removed, so send the full set of rows for the week.'],

    # --- Incidents (rmincident) -----------------------------------------
    ['list_incidents', :get, '/rmincident/index.json',
     'List resident incidents with their date, type, location, status and reporting staff. Defaults to the current month. query: rm_resident_id, location_id, incident_type, incident_status (N new, S submitted, A approved), period_type, period, from, to, offset, limit.'],
    ['get_incident', :get, '/rmincident/edit.json',
     'Get one incident with its description, witnesses, injuries, actions, resident details and submit/approve signatures. query: id, or rm_resident_id alone to start a new one for that resident.'],
    ['create_incident', :post, '/rmincident/update.json',
     'Report an incident. body {"incident": {"rm_resident_id", "incident_date", "incident_type_id", "location", "desc", "witnesses", "injuries", "imm_action", "notes", "follow_up", "prev_action", "reported_by_id"}}. rm_resident_id and incident_date are required; incident_type_id is an enumeration id of type RIT. Omit "id" to create. Saving submits the incident, after which only approval is allowed. The response is the new incident id.'],
    ['update_incident', :post, '/rmincident/update.json',
     'Update or approve an incident. body {"incident": {"id", ...same fields as create_incident}}. Send "approve_incident": true to approve instead; an approved incident is read-only, and a submitted one can only be approved.'],

    # --- Evaluations (rmevaluation) -------------------------------------
    ['list_resident_evaluations', :get, '/rmevaluation/index.json',
     'List resident evaluations (surveys targeted at residents) with their status and recurrence. query: survey_name, status (N new, O open, C closed, A archived), rm_resident_id to narrow to one resident\'s evaluations plus the generic ones, offset, limit. Evaluations are created, answered and scored through the ERPmine survey tools — this endpoint is read-only.'],

    # --- Dashboard (rmdashboard) ----------------------------------------
    ['list_resident_dashboard_graphs', :get, '/rmdashboard/get_graphs.json',
     'List the resident dashboard graphs with their data — move-ins vs move-outs, incidents by type and bed occupancy. query: from, to, location_id. Defaults to the last 12 months.'],
    ['get_resident_dashboard_graph_detail', :get, '/rmdashboard/get_detail_report.json',
     'Get the drill-down rows behind one resident dashboard graph. query: gPath (the graph path from list_resident_dashboard_graphs), from, to, location_id.'],

    # --- Lookups --------------------------------------------------------
    ['list_location_apartments', :get, '/rmresident/locationApartments.json',
     'List the vacant apartments at a location, as value/label pairs. query: location_id. Resolves apartment_idM for the move-in and transfer tools; omit location_id to list occupied apartments instead.'],
    ['list_apartment_beds', :get, '/rmresident/apartmentBeds.json',
     'List the beds in one apartment, as value/label pairs. query: apartment_id, resMoveIn ("true" to list only vacant beds). Resolves bed_idM for the move-in and transfer tools.'],
    ['get_bed_rate', :get, '/rmresident/bedRate.json',
     'Get the rent rate and rate period for a bed, or for the apartment when it has no beds. query: apartment_id, bed_id. Resolves rateM for the move-in and transfer tools.'],
    ['list_residents_by_location', :get, '/rmincident/get_residents_by_location.json',
     'List the current residents at a location, as id/name pairs. query: location_id (an exact leaf location, not a parent zone); omit it for every current resident. Resolves rm_resident_id for the incident tools.'],
    ['get_resident_summary', :get, '/rmincident/get_resident_info.json',
     'Get one resident\'s move-in date, location, apartment and bed. query: rm_resident_id. The short form used on the incident screen; use get_resident for the full record.'],
    ['search_service_issues', :get, '/rmperformservice/getissues.json',
     'Search the resident-service issues that service time can be logged against, as id/label pairs. query: user_id, term (subject or issue number to match), project_id, startday. Resolves issue_id for the service-entry write tools.'],
    ['list_service_activities', :get, '/rmperformservice/getactivities',
     'List the time-entry activities valid for the resident-service project, as id/name pairs. query: project_id, or issue_id together with user_id. Resolves activity_id for the service-entry write tools. Note this path has no .json suffix — the endpoint answers JSON only when no format is given.']
  ].freeze

  # Hook entry point. redmine_mcp's catalogue merges the returned rows.
  def redmine_mcp_register_tools(context = {})
    ENDPOINTS
  end

  # Which plugin these tools belong to. redmine_mcp's settings page lists the
  # rows above under this plugin's name, in their own table, instead of mixing
  # them into the core Redmine tool list (see RedmineMcp::Catalog#group_label).
  def mcp_plugin_id
    :erpmine_resident
  end
end
