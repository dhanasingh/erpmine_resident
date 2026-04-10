class AddResidentPermissions < ActiveRecord::Migration[7.2]
  def change
    reversible do |dir|
      dir.up do
        perms = [
          { name: 'BASIC RESIDENT PRIVILEGE', short_name: 'B_RES_PRVLG', modules: 'Resident', plugin: 'rm' },
          { name: 'ADMIN RESIDENT PRIVILEGE', short_name: 'A_RES_PRVLG', modules: 'Resident', plugin: 'rm' },

          { name: 'BASIC APARTMENT PRIVILEGE', short_name: 'B_APT_PRVLG', modules: 'Apartment', plugin: 'rm' },
          { name: 'ADMIN APARTMENT PRIVILEGE', short_name: 'A_APT_PRVLG', modules: 'Apartment', plugin: 'rm' },

          { name: 'BASIC INCIDENT PRIVILEGE', short_name: 'B_INC_PRVLG', modules: 'Incident', plugin: 'rm' },
          { name: 'ADMIN INCIDENT PRIVILEGE', short_name: 'A_INC_PRVLG', modules: 'Incident', plugin: 'rm' },

          { name: 'BASIC EVALUATION PRIVILEGE', short_name: 'B_EVL_PRVLG', modules: 'Evaluation', plugin: 'rm' },
          { name: 'ADMIN EVALUATION PRIVILEGE', short_name: 'A_EVL_PRVLG', modules: 'Evaluation', plugin: 'rm' },

          { name: 'VIEW SERVICE', short_name: 'V_SVC', modules: 'Service', plugin: 'rm' }
        ]

        # Add new ones
        perms.each do |perm|
          next if WkPermission.exists?(short_name: perm[:short_name])

          perm[:id] = (WkPermission.unscoped.maximum(:id) || 0) + 1
          WkPermission.create!(perm) rescue puts "Failed: #{perm[:short_name]} "
        end
      end

      dir.down do
        WkPermission.where(
          short_name: ['B_RES_PRVLG', 'A_RES_PRVLG', 'B_APT_PRVLG', 'A_APT_PRVLG', 'B_INC_PRVLG', 'A_INC_PRVLG', 'B_EVL_PRVLG', 'A_EVL_PRVLG', 'V_SVC']
        ).destroy_all
      end
    end
  end
end