## ADDED Requirements

### Requirement: Define standard creator sub-roles
The backend SHALL enforce a standard set of sub-roles for users who register or operate as a `creator`. The available sub-roles MUST include Institusi, Pemerintah, MC, Penyanyi, Wedding Organizer, Event Organizer, and Komunitas.

#### Scenario: Sub-roles are available in the system
- **WHEN** the system initializes or migrates
- **THEN** the predefined sub-roles exist in the `sub_role_categories` table and are strictly mirrored in the backend enum

### Requirement: Map dynamic categories to application logic
The backend enum `App\Enums\CreatorSubRole` SHALL correctly map the dynamic database slugs to their corresponding labels to be used in validation and logic.

#### Scenario: Validating a creator sub-role
- **WHEN** validating a sub-role during registration or profile update
- **THEN** the system uses the enum definitions to ensure the sub-role is allowed
