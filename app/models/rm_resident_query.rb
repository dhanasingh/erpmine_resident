class RmResidentQuery < Query

self.queried_class = RmResident


	self.available_columns = [
	QueryColumn.new(:resident_id),
	QueryColumn.new(:resident_type),
	QueryAssociationColumn.new(:resident, :location, :caption => :field_tracker),
	QueryColumn.new(:apartment_id),
	QueryColumn.new(:bed_id),
    QueryColumn.new(:move_in_date),
	QueryColumn.new(:move_out_date),
  ]

	def initialize(attributes=nil, *args)
		super attributes
		self.filters ||= {}
		add_filter('move_in_date', '*') unless filters.present?
		add_filters('move_out_date', '*') unless filters.present?
	end

	def initialize_available_filters
		add_available_filter "move_in_date", :type => :date_past
		add_available_filter "move_out_date", :type => :date_past
		
		locations = WkLocation.order(:name)
		#add_available_filter("resident_id", :type => :tree, :label => :field_resident_id)
		add_available_filter("resident.location_id",
		  :type => :list,
		  :name => l(:field_resident_type),
		  :values => lambda { locations.map {|t| [t.name, t.id.to_s]} })		
	end
	
	def default_columns_names   
		@default_columns_names ||= [:resident_id, :resident_type, :apartment_id, :bed_id,:move_in_date, :move_out_date]
	end

	def base_scope
		RmResident.
		includes(:resident).
		left_join_contacts.
		where(statement)
	end

	def results_scope(options={})
		order_option = [group_by_sort_order, (options[:order] || sort_clause)].flatten.reject(&:blank?)

		base_scope.
		order(order_option)
	end
	
	def sql_for_resident_location_id_field(field, operator, value)
		sql_for_field("location_id", operator, value, WkCrmContact.table_name, "location_id")
	 end
end