## ADDED Requirements

### Requirement: KTP OCR text extraction
The system SHALL extract text from KTP images using Google ML Kit text recognition API when a user uploads a KTP photo.

#### Scenario: Successful OCR processing
- **WHEN** user uploads a KTP photo
- **THEN** system processes the image with Google ML Kit text recognition
- **AND** system displays a loading indicator during processing
- **AND** system extracts all visible text from the image

#### Scenario: OCR processing error
- **WHEN** OCR processing fails due to image quality or system error
- **THEN** system displays an error message to the user
- **AND** system allows user to proceed with manual input
- **AND** system does not block form submission

### Requirement: KTP data field extraction
The system SHALL parse extracted OCR text to identify and extract KTP data fields: NIK, Nama Lengkap, Tempat Lahir, Tanggal Lahir, and Alamat.

#### Scenario: NIK extraction
- **WHEN** OCR text contains a 16-digit number matching NIK pattern
- **THEN** system extracts the number as NIK
- **AND** system populates the NIK form field

#### Scenario: Name extraction
- **WHEN** OCR text contains text matching name pattern (typically labeled "Nama")
- **THEN** system extracts the text as Nama Lengkap
- **AND** system populates the Nama Lengkap form field

#### Scenario: Birth place extraction
- **WHEN** OCR text contains text matching birth place pattern (typically labeled "Tempat Lahir")
- **THEN** system extracts the text as Tempat Lahir
- **AND** system populates the Tempat Lahir form field

#### Scenario: Birth date extraction
- **WHEN** OCR text contains text matching date pattern (DD-MM-YYYY or similar)
- **THEN** system extracts and parses the date
- **AND** system populates the Tanggal Lahir form fields (Day, Month, Year)

#### Scenario: Address extraction
- **WHEN** OCR text contains text matching address pattern (typically labeled "Alamat")
- **THEN** system extracts the text as Alamat
- **AND** system populates the Alamat form field

### Requirement: Manual correction of OCR results
The system SHALL allow users to manually edit all form fields populated by OCR extraction.

#### Scenario: User edits OCR-populated field
- **WHEN** user modifies any form field that was auto-populated by OCR
- **THEN** system accepts the manual input
- **AND** system uses the manual input for form submission
- **AND** system does not revert to OCR-extracted value

#### Scenario: User clears OCR-populated field
- **WHEN** user clears a form field that was auto-populated by OCR
- **THEN** system accepts the cleared field
- **AND** system treats it as empty for validation

### Requirement: OCR processing feedback
The system SHALL provide visual feedback during OCR processing to inform users of the system state.

#### Scenario: Loading indicator during OCR
- **WHEN** OCR processing is in progress
- **THEN** system displays a loading indicator on the KTP upload area
- **AND** system disables the upload button during processing

#### Scenario: OCR completion notification
- **WHEN** OCR processing completes successfully
- **THEN** system removes the loading indicator
- **AND** system populates form fields with extracted data
- **AND** system displays a brief success message indicating auto-fill occurred

#### Scenario: OCR error notification
- **WHEN** OCR processing fails
- **THEN** system removes the loading indicator
- **AND** system displays an error message explaining the failure
- **AND** system suggests manual input as alternative
