import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import '../lib/models/opportunity_application_model.dart';
import '../lib/models/opportunity_model.dart';
import '../lib/services/contract_pdf_service.dart';
import '../lib/widgets/app_pagination_bar.dart';

void main() {
  group('1 Orang 1 Kontrak Digital (3 Pihak) & Template Resmi A4', () {
    test('Supports 13 approved applicants with 1-to-1 individual contracts & pagination', () {
      final apps = List.generate(13, (i) {
        final idx = i + 1;
        final isSignedBoth = idx <= 10;
        return OpportunityApplicationModel.fromJson({
          'id': 'app-id-$idx',
          'opportunity_id': 'opp-1001',
          'creator_id': 'creator-$idx',
          'creator': {
            'id': 'creator-$idx',
            'name': 'Pelamar Kreatif $idx',
            'username': 'pelamar_$idx',
            'sub_role': 'videographer',
          },
          'sub_role_slug': 'videographer',
          'pitch_message': 'Siap bekerja profesional #$idx',
          'bid_price': 2500000,
          'status': 'approved',
          'contract_number': 'KVN/TAK/CTR/20261115/OPP1-APP$idx',
          'client_signature': isSignedBoth ? 'SIG-CLIENT-$idx' : null,
          'client_signed_at': isSignedBoth ? '2026-11-15T10:00:00Z' : null,
          'creator_signature': isSignedBoth ? 'SIG-CREATOR-$idx' : null,
          'creator_signed_at': isSignedBoth ? '2026-11-15T10:05:00Z' : null,
          'dynamic_terms': [
            'Klausul khusus individu untuk Pelamar $idx',
          ],
        });
      });

      expect(apps.length, 13);
      expect(apps.where((a) => a.isContractFinal).length, 10);
      expect(apps.where((a) => !a.isContractFinal).length, 3);

      // Verify unique contract numbers (1 person = 1 contract)
      final contractNumbers = apps.map((a) => a.contractNumber).toSet();
      expect(contractNumbers.length, 13);

      // Verify pagination for 13 contracts with pageSize 5 (3 pages: 5, 5, 3)
      expect(AppPaginationBar.totalPages(apps.length, pageSize: 5), 3);
      expect(AppPaginationBar.slicePage(apps, 1, pageSize: 5).length, 5);
      expect(AppPaginationBar.slicePage(apps, 2, pageSize: 5).length, 5);
      expect(AppPaginationBar.slicePage(apps, 3, pageSize: 5).length, 3);
    });

    test('OpportunityApprovedCreatorModel parses individual contract fields & finality lock', () {
      final unsignedModel = OpportunityApprovedCreatorModel.fromJson({
        'id': 'creator-1',
        'application_id': 'app-1',
        'name': 'Budi Santoso',
        'username': 'budi_s',
        'sub_role': 'photographer',
        'agreed_price': 3500000,
        'contract_number': 'KVN/TAK/CTR/20261115/OPP1-APP1',
        'client_signature': 'SIG-CLIENT-1',
        'client_signed_at': '2026-11-15T08:00:00Z',
        'creator_signature': null,
        'creator_signed_at': null,
      });

      expect(unsignedModel.isClientSigned, isTrue);
      expect(unsignedModel.isSigned, isFalse);
      expect(unsignedModel.isContractFinal, isFalse);

      final finalModel = OpportunityApprovedCreatorModel.fromJson({
        'id': 'creator-1',
        'application_id': 'app-1',
        'name': 'Budi Santoso',
        'username': 'budi_s',
        'sub_role': 'photographer',
        'agreed_price': 3500000,
        'contract_number': 'KVN/TAK/CTR/20261115/OPP1-APP1',
        'client_signature': 'SIG-CLIENT-1',
        'client_signed_at': '2026-11-15T08:00:00Z',
        'creator_signature': 'SIG-CREATOR-1',
        'creator_signed_at': '2026-11-15T08:15:00Z',
        'dynamic_terms': ['Kamera disiapkan penyelenggara'],
      });

      expect(finalModel.isClientSigned, isTrue);
      expect(finalModel.isSigned, isTrue);
      expect(finalModel.isContractFinal, isTrue);
      expect(finalModel.contractNumber, 'KVN/TAK/CTR/20261115/OPP1-APP1');
      expect(finalModel.agreedPrice, 3500000);
    });

    test('ContractPdfService generates valid A4 PDF with CV Transforma Alam Kreasi header and Aplikasi Kreavana source', () {
      const docData = OfficialContractDocumentData(
        contractNumber: 'KVN/TAK/CTR/20261115/AB12-CD34',
        projectTitle: 'Dokumentasi Konser Musik Nusantara 2026',
        projectDescription: 'Peliputan multicam dan aftermovie resmi.',
        projectLocation: 'Jakarta Convention Center',
        projectSchedule: '2026-12-20',
        agreedPrice: 5000000,
        paymentSchemeLabel: 'Pembayaran Sekaligus (100% Setelah Pekerjaan Selesai)',
        clauses: [
          'Penyelenggara menyediakan akses all-area bagi pekerja.',
          'Pekerja wajib menyerahkan hasil akhir maksimal H+5.',
        ],
        isFinal: true,
        issuedDateText: '15 November 2026',
        clientName: 'Kreavana Demo Institution',
        clientUsername: 'smk_telesandi',
        clientRoleLabel: 'Penyelenggara Acara (Pihak Pertama)',
        clientSignature: 'DIGITAL_SIGNATURE:Kreavana Demo Institution:2026-11-15',
        clientSignedAtText: '15 November 2026, 10:00 WIB',
        creatorName: 'Andi Videografer',
        creatorUsername: 'andi_video',
        creatorSubRoleLabel: 'Videografer',
        creatorSignature: 'DIGITAL_SIGNATURE:Andi Videografer:2026-11-15',
        creatorSignedAtText: '15 November 2026, 10:15 WIB',
        adminSignedAtText: '15 November 2026, 10:15 WIB',
      );

      final pdfBytes = ContractPdfService.buildOfficialContractA4PdfBytes(docData);
      final pdfText = ascii.decode(pdfBytes);

      expect(pdfText.startsWith('%PDF-1.4'), isTrue);
      expect(pdfText.contains('/MediaBox [0 0 595 842]'), isTrue);
      expect(pdfText.contains('CV TRANSFORMA ALAM KREASI'), isTrue);
      expect(pdfText.contains('Aplikasi Kreavana'), isTrue);
      expect(pdfText.contains('KVN/TAK/CTR/20261115/AB12-CD34'), isTrue);
      expect(pdfText.contains('KONTRAK FIX \\(FINAL\\)'), isTrue);
      expect(pdfText.contains('Andi Videografer'), isTrue);
      expect(pdfText.contains('15 November 2026'), isTrue);
    });
  });
}
