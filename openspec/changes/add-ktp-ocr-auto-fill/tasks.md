## 1. Setup

- [x] 1.1 Add google_ml_kit dependency to pubspec.yaml
- [x] 1.2 Run flutter pub get to install new dependency
- [x] 1.3 Create KTP OCR service class (ktp_ocr_service.dart)

## 2. OCR Service Implementation

- [x] 2.1 Implement text recognition function using Google ML Kit
- [x] 2.2 Add NIK extraction regex pattern (16 digits)
- [x] 2.3 Add name extraction regex pattern
- [x] 2.4 Add birth place extraction regex pattern
- [x] 2.5 Add birth date extraction regex pattern (DD-MM-YYYY)
- [x] 2.6 Add address extraction regex pattern
- [x] 2.7 Implement data parsing function to extract all KTP fields
- [x] 2.8 Add error handling for OCR failures
- [x] 2.9 Add loading state management

## 3. CreatorApplicationCard Integration

- [x] 3.1 Import KTP OCR service in creator_application_card.dart
- [x] 3.2 Add OCR processing state variable (_isProcessingOCR)
- [x] 3.3 Modify _pickKtpPhoto to trigger OCR after image selection
- [x] 3.4 Add loading indicator during OCR processing
- [x] 3.5 Implement auto-population of form fields with OCR results
- [x] 3.6 Add success message when OCR completes successfully
- [x] 3.7 Add error message when OCR fails
- [x] 3.8 Ensure manual correction of OCR-populated fields works correctly

## 4. Testing

- [ ] 4.1 Test OCR with clear KTP image
- [ ] 4.2 Test OCR with blurry KTP image
- [ ] 4.3 Test OCR with different KTP formats
- [ ] 4.4 Test manual correction of OCR results
- [ ] 4.5 Test error handling when OCR fails
- [ ] 4.6 Test loading indicator display
- [ ] 4.7 Test form validation with OCR-populated data
