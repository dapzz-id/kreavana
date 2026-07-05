## MODIFIED Requirements

### Requirement: Role mapping assigns appropriate properties
The system SHALL set the user's role and validate the provided `sub_role` upon creator application or selection. The sub-role MUST match one of the predefined sub-roles.

#### Scenario: Applying as a specific creator type
- **WHEN** a user with role `user` submits a creator application
- **THEN** the application verifies that their chosen `sub_role` is a valid entry from the expanded `CreatorSubRole` enum

### Requirement: API Route authorization with Sub-Roles
The system SHALL support API route protection based on both generic roles and specific sub-roles.

#### Scenario: Restricting an endpoint to specific creator type
- **WHEN** an endpoint is configured to require a specific sub-role (e.g., `pemerintah`)
- **THEN** only users with `role: creator` and `sub_role: pemerintah` are granted access, while other generic creators or users receive a standard Unauthorized response.
