## Why

Users currently need to manually fill all KTP verification form fields (NIK, Nama, Tempat Lahir, Tanggal Lahir, Alamat) after uploading a KTP photo. This is time-consuming and error-prone. Adding OCR (Optical Character Recognition) will automatically extract data from KTP images and populate the form fields, improving user experience and reducing manual input errors.

## What Changes

- Add Google ML Kit dependency for text recognition
- Implement OCR processing when KTP photo is uploaded
- Parse OCR results to extract KTP data fields (NIK, Nama, Tempat Lahir, Tanggal Lahir, Alamat)
- Auto-populate form fields with extracted data
- Allow users to manually correct OCR results
- Add loading indicator during OCR processing
- Handle OCR errors gracefully with fallback to manual input

## Capabilities

### New Capabilities
- `ktp-ocr`: Automatic KTP data extraction using Google ML Kit text recognition

### Modified Capabilities
- None (this is a new feature, not a requirement change to existing specs)

## Impact

- **Frontend**: Add `google_ml_kit` package dependency, modify `creator_application_card.dart` to implement OCR processing
- **User Experience**: Faster KTP verification process with reduced manual input
- **Dependencies**: Google ML Kit (free, client-side OCR)
- **Performance**: OCR processing happens on device (offline/online), minimal backend impact
