# lib/tasks/erpmine_resident_setup.rake
namespace :resident do
  desc "Load init Resident data"

  task load_default_data: :environment do

    # --- Skip if already present ---
    if (Setting.plugin_erpmine_resident || {})['rm_project'].present? || WkProduct.where("name LIKE ?", "%Apartment%").exists? || WkProduct.where("name LIKE ?", "%Bed%").exists?
      mlog "Failed to load, data already exists."
      exit
    end

    Project.transaction do
      begin
        config_setup
        apartment_setup
        mlog "Successfully Resident default data loaded."
      rescue => e
        mlog "Failed to load, error: #{e.message}"
        raise ActiveRecord::Rollback
      end
    end
  end

  def config_setup
    # --- Setup resident permissions ---
    group = Group.create!(name: 'Resident Admin')
    # Add the sole user (if exactly one user exists) and that user is admin
    group.users << User.admin.first if User.admin.exists? && User.admin.length == 1
    perm_short_names = ['B_RES_PRVLG', 'A_RES_PRVLG','B_APT_PRVLG', 'A_APT_PRVLG',
    'B_INC_PRVLG', 'A_INC_PRVLG','B_EVL_PRVLG', 'A_EVL_PRVLG','V_SVC']
     permissions = WkPermission.where(short_name: perm_short_names)
     permissions.each do |perm|
      WkGroupPermission.find_or_create_by!(group_id: group.id, permission_id: perm.id)
    end

    # --- Create project ---
    project = Project.new
    if Project.exists?(identifier: 'resident')
      project.identifier = 'resident-default'
      project.name = 'Resident-default'
    else
      project.identifier = 'resident'
      project.name       = 'Resident'
    end
    project.description = 'Resident Management'
    project.is_public = false
    project.enabled_module_names = Redmine::AccessControl.available_project_modules
    project.save!

    # --- Create trackers ---
    ['Rental', 'Service', 'Amenity', 'Care'].each do |name|
      tracker = Tracker.find_or_initialize_by(name: name)
      tracker.default_status_id = IssueStatus.first.id
      tracker.core_fields = Tracker::CORE_FIELDS
      tracker.save!
      unless tracker.projects.include?(project)
        tracker.projects << project
      end
    end

    # --- Create Issues for trackers ---
    issues = {
      'Rental' => ['Rent Payment'],
      'Service' => ['ADL support ', 'Housekeeping and laundry', 'Medication management', 'Dining and nutrition services', 'Therapy services'],
      'Amenity' => ['Fitness studio and wellness spaces', 'Library and computer room', 'WiFi', 'cinema', 'meditation room', 'Shuttle', 'Salon and spa']
    }
    issues.each do |name, subjects|
      tracker = Tracker.find_by(name: name)
      subjects.each do |subject|
        issue = Issue.new
        issue.subject = subject
        issue.project_id = project.id
        issue.tracker_id = tracker.id
        issue.author_id = User.admin.first.id
        issue.status_id = IssueStatus.first.id
        issue.save!
      end
    end

    # --- Create Care level issues with min/max points ---
    care_levels = [
      { subject: 'Care Level 1', min_points: 0,  max_points: 25  },
      { subject: 'Care Level 2', min_points: 26, max_points: 50  },
      { subject: 'Care Level 3', min_points: 51, max_points: 75  },
      { subject: 'Care Level 4', min_points: 76, max_points: 100 }
    ]
    care_tracker = Tracker.find_by(name: 'Care')
    care_levels.each do |level|
      issue = Issue.new
      issue.subject    = level[:subject]
      issue.project_id = project.id
      issue.tracker_id = care_tracker.id
      issue.author_id  = User.admin.first.id
      issue.status_id  = IssueStatus.first.id
      issue.save!
      WkIssue.find_or_create_by!(issue_id: issue.id) do |wi|
        wi.project_id = project.id
        wi.min_points = level[:min_points]
        wi.max_points = level[:max_points]
      end
    end

    # --- Update settings ---
    Setting.plugin_erpmine_resident = {
      'rm_project' => project.id,
      'rm_rental_tracker' => Tracker.find_by(name: 'Rental')&.id,
      'rm_service_tracker' => Tracker.find_by(name: 'Service')&.id,
      'rm_amenity_tracker' => Tracker.find_by(name: 'Amenity')&.id,
      'rm_care_tracker'    => Tracker.find_by(name: 'Care')&.id
    }
  end

  def apartment_setup
    # --- Apartment and beds setup ---
    category = WkProductCategory.find_or_create_by!(name: 'Resident')
    uom = WkMesureUnit.find_or_create_by!(name: 'Numbers', short_desc: 'No')
    attr = WkAttributeGroup.find_or_create_by!(name: '	Care level')
    apartment = WkProduct.find_or_create_by!(name: 'Apartment', category_id: category.id, product_type: 'RA', uom_id: uom.id, attribute_group_id: attr.id)
    bed = WkProduct.find_or_create_by!(name: 'Bed', category_id: category.id, product_type: 'RA', uom_id: uom.id, attribute_group_id: attr.id)

    # --- Move out reason setup ---
    ['Relocation', 'Deceased', 'Financial reasons', 'Other'].each do |reason|
      WkCrmEnumeration.find_or_create_by!(name: reason, enum_type: 'MOR', active: true)
    end 
  end

  def mlog(message)
    puts message
    Rails.logger.info message
  end
end
