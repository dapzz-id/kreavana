import 'package:flutter_test/flutter_test.dart';
import 'package:kreavana/widgets/program_magang_card.dart';
import 'package:kreavana/models/opportunity_model.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  group('ProgramMagangCard Date Formatting Tests', () {
    test('formats YYYY-MM-DD to d MMM yyyy (e.g. 21 Sep 2026)', () {
      expect(ProgramMagangCard.formatDateDisplay('2026-09-21'), '21 Sep 2026');
      expect(ProgramMagangCard.formatDateDisplay('2026-12-23'), '23 Des 2026');
    });

    test('retains already formatted d MMM yyyy (21 Sep 2026)', () {
      expect(ProgramMagangCard.formatDateDisplay('21 Sep 2026'), '21 Sep 2026');
    });

    test('falls back to default fallback 21 Sep 2026 when null or empty', () {
      expect(ProgramMagangCard.formatDateDisplay(null), '21 Sep 2026');
      expect(ProgramMagangCard.formatDateDisplay(''), '21 Sep 2026');
      expect(ProgramMagangCard.formatDateDisplay('   '), '21 Sep 2026');
    });

    test('fromOpportunity formats deadline into d MMM yyyy', () {
      final opp = OpportunityModel(
        id: 'opp-1',
        title: 'Program Magang MBKM 3D Modeler Batch I 2026',
        subRoleSlug: 'animator',
        deadline: '2026-09-21',
      );

      final card = ProgramMagangCard.fromOpportunity(opp);
      expect(card.registrationPeriod, '21 Sep 2026');
    });
  });
}

