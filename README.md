# ERPmine Resident Management

This Plugin has the following module:

- Resident
- Create Leads
- Move In Resident
- Move Out Resident
- Transfer Resident
- Perform Services
- Generate Bills
- Receive Payments
- Evaluation
- Incident

## Installation

- Unpack the zip file to the plugins folder of Redmine. It requires db migration.

- Run the following command for db migration

  ```sh
  bundle exec rake redmine:plugins:migrate NAME=erpmine_resident RAILS_ENV=production
  ```
- Run the following command to load default data

  ```sh
  bundle exec rake resident:load_default_data RAILS_ENV=production
  ```
## Uninstallation

- When uninstalling the plugin, be sure to remove the db changes by running
  ```sh
  bundle exec rake redmine:plugins:migrate NAME=erpmine_resident VERSION=0 RAILS_ENV=production
  ```

- This plugin uses js and css assets and it will be copied to public/plugin_asset/erpmine_resident
  folder upon server startup, so please make sure public/plugin_asset/erpmine_resident has proper access.

## Compatibility Matrix

| **Resident** | **ERPmine** |
|-------------|-------------|
| 2.0 | 5.0 |
| 1.4.1 | 4.9.4 |
| 1.4 | 4.9.3 |
| 1.3 | 4.9.2 |
| 1.2 | 4.9, 4.9.1 |
| 1.1 | 4.8.4, 4.8.5 |
| 1.0 | 4.8.3 |

## Release Notes for v2.0

**Features**
```text
- Redmine 7.0 compatibility
```
## Dependency:

  This plugin is compatible with ERPmine v5.0

## Customization:

  For any Customization/Support, please contact us, our consulting team will be happy to help you

  Adhi Software Pvt Ltd
  12/B-35, 6th Cross Road
  SIPCOT IT Park, Siruseri
  Kancheepuram Dist
  Tamilnadu - 603103
  India

  Website: http://www.adhisoftware.co.in
  Email: info@adhisoftware.co.in
  Phone: +91 44 27470401

## Resources:

**Training Videos**:

- https://www.youtube.com/watch?v=CHAgSMmkKBE

- https://www.youtube.com/watch?v=hTgDepFzGXY

- https://www.youtube.com/watch?v=5IgBbhrVF4k

**For more**:

- http://www.erpmine.org/projects/erpmine/wiki/Resources
