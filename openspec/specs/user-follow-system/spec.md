## Purpose
Defines the user follow system, allowing users to follow each other and view follower statistics.

## ADDED Requirements

### Requirement: Users can follow other users
The system SHALL allow any authenticated user to follow or unfollow another user's account.

#### Scenario: User follows another user
- **WHEN** an authenticated user sends a follow request to a target user ID
- **THEN** the system creates a follow relationship and returns success

#### Scenario: User unfollows a followed user
- **WHEN** an authenticated user sends an unfollow request
- **THEN** the system removes the follow relationship

#### Scenario: User cannot follow themselves
- **WHEN** a user attempts to follow their own user ID
- **THEN** the system returns a 422 error with a generic message

#### Scenario: Duplicate follows are idempotent
- **WHEN** a user attempts to follow someone they already follow
- **THEN** the system returns success without creating a duplicate

### Requirement: Follow counts are visible on profiles
The system SHALL expose follower and following counts as part of the user profile response.

#### Scenario: Profile response includes follow counts
- **WHEN** any client fetches a user profile
- **THEN** the response includes `followers_count` and `following_count` integer fields

### Requirement: Followers and following lists are retrievable
The system SHALL provide paginated lists of a user's followers and users they are following.

#### Scenario: Fetch followers list
- **WHEN** a client requests `GET /api/users/{userId}/followers`
- **THEN** the system returns a paginated list of users who follow the specified user

#### Scenario: Fetch following list
- **WHEN** a client requests `GET /api/users/{userId}/following`
- **THEN** the system returns a paginated list of users the specified user follows
