## Context

The CreatorApplicationCard currently requires users to manually fill all KTP verification form fields after uploading a KTP photo. This process is time-consuming and prone to user input errors. The application uses Flutter with a Laravel backend, and the form is implemented in `frontend/lib/widgets/creator_application_card.dart`.

## Goals / Non-Goals

**Goals:**
- Automatically extract KTP data (NIK, Nama, Tempat Lahir, Tanggal Lahir, Alamat) from uploaded images using OCR
- Populate form fields with extracted data to reduce manual input
- Allow users to manually correct OCR results when needed
- Provide clear feedback during OCR processing (loading indicators, error messages)
- Ensure OCR processing happens client-side for privacy and performance

**Non-Goals:**
- Backend OCR processing (all processing stays on device)
- Verification of extracted data accuracy (users remain responsible for correctness)
- OCR for other document types (only KTP)
- Offline-only OCR (will support both offline and online modes)

## Decisions

**Google ML Kit for Text Recognition**
- **Choice**: Use Google ML Kit's text recognition API
- **Rationale**: Free, client-side processing, supports Indonesian text, well-maintained Flutter package, no backend dependency
- **Alternatives considered**:
  - Tesseract (open source but requires complex setup and training for Indonesian KTP)
  - Backend OCR services (adds latency, cost, and privacy concerns)

**OCR Processing Flow**
- **Choice**: Process OCR immediately after image selection, before form display
- **Rationale**: Provides instant feedback, allows users to see and correct extracted data immediately
- **Alternatives considered**:
  - Process on form submission (delayed feedback, poor UX)
  - Process in background (complex state management)

**Data Extraction Strategy**
- **Choice**: Use regex patterns to parse OCR text for KTP fields
- **Rationale**: KTP has consistent format patterns (NIK: 16 digits, dates: DD-MM-YYYY, etc.)
- **Alternatives considered**:
  - ML-based field classification (overkill, requires training data)
  - Manual field selection (poor UX)

**Error Handling**
- **Choice**: Graceful degradation - if OCR fails, show error and allow manual input
- **Rationale**: Ensures users can always complete verification regardless of OCR success
- **Alternatives considered**:
  - Block form until OCR succeeds (prevents completion on poor images)
  - Retry automatically (could cause frustration)

## Risks / Trade-offs

**[Risk] OCR accuracy varies with image quality** → Mitigation: Add image quality tips, allow manual correction, provide clear error messages

**[Risk] Indonesian KTP format variations** → Mitigation: Use flexible regex patterns, test with various KTP samples, allow manual override

**[Risk] OCR processing time on older devices** → Mitigation: Show loading indicator, process asynchronously, allow cancellation

**[Trade-off] Client-side processing increases app size** → Mitigation: Google ML Kit is optimized, size increase is acceptable (~5-10MB)

**[Trade-off] Regex-based parsing may miss edge cases** → Mitigation: Test extensively, update patterns based on real KTP samples, manual correction always available

## Migration Plan

1. Add `google_ml_kit` dependency to pubspec.yaml
2. Implement OCR service class in Flutter
3. Modify CreatorApplicationCard to integrate OCR processing
4. Add loading states and error handling
5. Test with various KTP images (good/poor quality, different formats)
6. Deploy to staging for user testing
7. Monitor OCR success rates and user corrections

**Rollback Strategy**: Remove OCR integration, revert to manual-only input (feature flag or code rollback)
