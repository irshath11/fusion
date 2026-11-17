/// WPS Master Registry containing official Work Permit Numbers, Personal Numbers,
/// Bank Names, and Bank Account Numbers for workforce payroll file generation.
class WpsEmployeeRecord {
  final String employeeCode;
  final String fullName;
  final String workPermitNo;
  final String personalNo;
  final String bankName;
  final String bankAccountNo;
  final String division; // 'Neo' or 'Fusion'
  final double defaultBasicSalary;

  const WpsEmployeeRecord({
    required this.employeeCode,
    required this.fullName,
    required this.workPermitNo,
    required this.personalNo,
    required this.bankName,
    required this.bankAccountNo,
    required this.division,
    required this.defaultBasicSalary,
  });
}

class WpsMasterRegistry {
  /// Master enterprise WPS records directly transcribed from company WPS payroll registers
  static const List<WpsEmployeeRecord> records = [
    // =========================================================================
    // FUSION NEO BUILDING CONTRACTING LLC (Mol No : 2846014)
    // =========================================================================
    WpsEmployeeRecord(
      employeeCode: 'N-1003',
      fullName: 'MUHAMMED RIYAS HUSSAIN HUSSAIN KASIM',
      workPermitNo: '133557603',
      personalNo: '10028070016760',
      bankName: 'NBAD',
      bankAccountNo: '5331-9101-8849-3364',
      division: 'Neo',
      defaultBasicSalary: 1200.0,
    ),
    WpsEmployeeRecord(
      employeeCode: 'N-1004',
      fullName: 'SHABI BISMILLAH BISMILLAH',
      workPermitNo: '133629427',
      personalNo: '10007039409537',
      bankName: 'NBAD',
      bankAccountNo: '5331-9101-0741-7023',
      division: 'Neo',
      defaultBasicSalary: 1200.0,
    ),
    WpsEmployeeRecord(
      employeeCode: 'N-1005',
      fullName: 'ADHAM BISMILLAH BISMILLAH',
      workPermitNo: '133784715',
      personalNo: '10019029824602',
      bankName: 'NBAD',
      bankAccountNo: '5331-9101-0544-2304',
      division: 'Neo',
      defaultBasicSalary: 1200.0,
    ),
    WpsEmployeeRecord(
      employeeCode: 'N-1006',
      fullName: 'IRSHATH AHAMED SHAIK ALLAVUDIN SHAIK ALLAVUDIN',
      workPermitNo: '134704785',
      personalNo: '10011079721140',
      bankName: 'NBAD',
      bankAccountNo: '5331-9101-8578-8212',
      division: 'Neo',
      defaultBasicSalary: 1500.0,
    ),
    WpsEmployeeRecord(
      employeeCode: 'N-1008',
      fullName: 'KAJAMOHIDEEN SAMSUDEEN',
      workPermitNo: '136616537',
      personalNo: '10017077291332',
      bankName: 'NBAD',
      bankAccountNo: '5331-9101-8437-4808',
      division: 'Neo',
      defaultBasicSalary: 1200.0,
    ),
    WpsEmployeeRecord(
      employeeCode: 'N-1009',
      fullName: 'ABDUL KABARKHAN ABDUL GAFOOR',
      workPermitNo: '136468727',
      personalNo: '10002058980829',
      bankName: 'ADCB',
      bankAccountNo: 'AE460030013494553910001',
      division: 'Neo',
      defaultBasicSalary: 1500.0,
    ),
    WpsEmployeeRecord(
      employeeCode: 'N-1010',
      fullName: 'KRISHNAN MAHAVISHNU',
      workPermitNo: '137372069',
      personalNo: '10015090011021',
      bankName: 'NBAD',
      bankAccountNo: '5331-9101-8785-8492',
      division: 'Neo',
      defaultBasicSalary: 1000.0,
    ),
    WpsEmployeeRecord(
      employeeCode: 'N-1011',
      fullName: 'KUTTHUS ABTHUL KANI',
      workPermitNo: '137373581',
      personalNo: '10003047390715',
      bankName: 'NBAD',
      bankAccountNo: '5331-9101-8149-8774',
      division: 'Neo',
      defaultBasicSalary: 1000.0,
    ),
    WpsEmployeeRecord(
      employeeCode: 'N-1012',
      fullName: 'Javeedu Raahuman Hameed',
      workPermitNo: '139991037',
      personalNo: '10029060013618',
      bankName: 'NBAD',
      bankAccountNo: '5331-9101-8648-6121',
      division: 'Neo',
      defaultBasicSalary: 1000.0,
    ),
    WpsEmployeeRecord(
      employeeCode: 'N-1013',
      fullName: 'Abhishek Sharama',
      workPermitNo: '140218482',
      personalNo: '10001020525949',
      bankName: 'NBAD',
      bankAccountNo: '5331-9101-8682-3786',
      division: 'Neo',
      defaultBasicSalary: 1200.0,
    ),
    WpsEmployeeRecord(
      employeeCode: 'N-1014',
      fullName: 'AHAMED MEERAN SHEIK ABDUL KADAR',
      workPermitNo: '143000018',
      personalNo: '10008098750910',
      bankName: 'ADCB',
      bankAccountNo: 'AE660030013440999810001',
      division: 'Neo',
      defaultBasicSalary: 1500.0,
    ),

    // =========================================================================
    // FUSION ELECTRO-MECHANICAL MAINTENANCE LLC (Mol No :803095)
    // =========================================================================
    WpsEmployeeRecord(
      employeeCode: '1004',
      fullName: 'MOHAMMED IBURAHIM BASEER AHAMED',
      workPermitNo: '56482458',
      personalNo: '10023119164955',
      bankName: 'FAB',
      bankAccountNo: 'AE450351831007179643001',
      division: 'Fusion',
      defaultBasicSalary: 2000.0,
    ),
    WpsEmployeeRecord(
      employeeCode: '1008',
      fullName: 'IBRAMSHA SATHAR SATHAR',
      workPermitNo: '61316468',
      personalNo: '10020108507569',
      bankName: 'NBAD',
      bankAccountNo: '5331-9100-1245-2503',
      division: 'Fusion',
      defaultBasicSalary: 1500.0,
    ),
    WpsEmployeeRecord(
      employeeCode: '1012',
      fullName: 'RAJA MOHAMMED MOHAMMED ALI',
      workPermitNo: '68549280',
      personalNo: '10015059681704',
      bankName: 'NBAD',
      bankAccountNo: '5331-9101-0422-3945',
      division: 'Fusion',
      defaultBasicSalary: 1500.0,
    ),
    WpsEmployeeRecord(
      employeeCode: '1021',
      fullName: 'MOHAMED AZARUDHEEN ANVAR ALI',
      workPermitNo: '75725360',
      personalNo: '10017059658720',
      bankName: 'NBAD',
      bankAccountNo: '5331-9100-1497-9271',
      division: 'Fusion',
      defaultBasicSalary: 1000.0,
    ),
    WpsEmployeeRecord(
      employeeCode: '1024',
      fullName: 'RAMESH GOPAL',
      workPermitNo: '87837723',
      personalNo: '10010067620686',
      bankName: 'NBAD',
      bankAccountNo: '5331-9100-1926-7672',
      division: 'Fusion',
      defaultBasicSalary: 1500.0,
    ),
    WpsEmployeeRecord(
      employeeCode: '1031',
      fullName: 'MOHAMED RIFAYE ABDUL JABAR',
      workPermitNo: '91928751',
      personalNo: '10014059926234',
      bankName: 'NBAD',
      bankAccountNo: '5331-9101-0230-1065',
      division: 'Fusion',
      defaultBasicSalary: 1000.0,
    ),
    WpsEmployeeRecord(
      employeeCode: '1036',
      fullName: 'MAHATHEER MOHAMED JAMAL MOHAMED',
      workPermitNo: '139419691',
      personalNo: '10016129795647',
      bankName: 'NBAD',
      bankAccountNo: '5331-9101-0476-8352',
      division: 'Fusion',
      defaultBasicSalary: 1200.0,
    ),
    WpsEmployeeRecord(
      employeeCode: '1038',
      fullName: 'MOHAMED ALI SHAIK MOHAMED MOHAMED ALI',
      workPermitNo: '98493638',
      personalNo: '10012027099441',
      bankName: 'NBAD',
      bankAccountNo: '5331-9101-0379-0639',
      division: 'Fusion',
      defaultBasicSalary: 1500.0,
    ),
    WpsEmployeeRecord(
      employeeCode: '1047',
      fullName: 'RAMAKRISHNAN KULANGARAVALAPPIL KUTTAN',
      workPermitNo: '107643238',
      personalNo: '10031037717651',
      bankName: 'NBAD',
      bankAccountNo: '5331-9101-0406-2335',
      division: 'Fusion',
      defaultBasicSalary: 1200.0,
    ),
    WpsEmployeeRecord(
      employeeCode: '1048',
      fullName: 'MUHAMMAD IRFAN FAQEER',
      workPermitNo: '108807803',
      personalNo: '20024099490302',
      bankName: 'NBAD',
      bankAccountNo: '5331-9101-0401-2520',
      division: 'Fusion',
      defaultBasicSalary: 1200.0,
    ),
    WpsEmployeeRecord(
      employeeCode: '1049',
      fullName: 'SANJAY KUMAR',
      workPermitNo: '109072383',
      personalNo: '10002089325090',
      bankName: 'NBAD',
      bankAccountNo: '5331-9101-0579-2351',
      division: 'Fusion',
      defaultBasicSalary: 1200.0,
    ),
    WpsEmployeeRecord(
      employeeCode: '1054',
      fullName: 'NOWFAL RIZWAN NAINA',
      workPermitNo: '116274873',
      personalNo: '10014059776692',
      bankName: 'NBAD',
      bankAccountNo: '5331-9101-0251-9500',
      division: 'Fusion',
      defaultBasicSalary: 1000.0,
    ),
    WpsEmployeeRecord(
      employeeCode: '1056',
      fullName: 'RAFI ULLAH KHAN',
      workPermitNo: '119869033',
      personalNo: '20001010103080',
      bankName: 'NBAD',
      bankAccountNo: '5331-9101-0590-2646',
      division: 'Fusion',
      defaultBasicSalary: 1200.0,
    ),
    WpsEmployeeRecord(
      employeeCode: '1057',
      fullName: 'Anandh Veeramani',
      workPermitNo: '126722688',
      personalNo: '10011119294124',
      bankName: 'NBAD',
      bankAccountNo: '5331-9101-0532-9733',
      division: 'Fusion',
      defaultBasicSalary: 1500.0,
    ),
    WpsEmployeeRecord(
      employeeCode: '1058',
      fullName: 'Al Naser Samsudeen',
      workPermitNo: '127445488',
      personalNo: '10007068473900',
      bankName: 'DIB',
      bankAccountNo: 'AE130240003580188455101',
      division: 'Fusion',
      defaultBasicSalary: 2000.0,
    ),
    WpsEmployeeRecord(
      employeeCode: '1059',
      fullName: 'Saleem Allapitchai',
      workPermitNo: '127555347',
      personalNo: '10013067424543',
      bankName: 'NBAD',
      bankAccountNo: '5331-9101-0642-4616',
      division: 'Fusion',
      defaultBasicSalary: 1200.0,
    ),
    WpsEmployeeRecord(
      employeeCode: '1060',
      fullName: 'Silambarasan',
      workPermitNo: '141489727',
      personalNo: '10002068808090',
      bankName: 'NBAD',
      bankAccountNo: '5331-9101-8207-4624',
      division: 'Fusion',
      defaultBasicSalary: 1000.0,
    ),
  ];

  /// Find matching WPS record by employee code or name
  static WpsEmployeeRecord? findRecord({String? code, String? name}) {
    final c = (code ?? '').trim().toUpperCase().replaceFirst('EMP-', '');
    final n = (name ?? '').trim().toLowerCase();

    for (final r in records) {
      if (c.isNotEmpty && (r.employeeCode.toUpperCase() == c || r.employeeCode.toUpperCase().replaceFirst('EMP-', '') == c)) {
        return r;
      }
    }

    if (n.isNotEmpty) {
      for (final r in records) {
        if (r.fullName.trim().toLowerCase() == n) {
          return r;
        }
      }
      for (final r in records) {
        final rName = r.fullName.trim().toLowerCase();
        if (rName.contains(n) || n.contains(rName)) {
          return r;
        }
      }
    }

    return null;
  }

  /// Get all records for a specific division ('Neo' or 'Fusion')
  static List<WpsEmployeeRecord> getByDivision(String division) {
    final div = division.trim().toLowerCase();
    return records.where((r) => r.division.toLowerCase() == div).toList();
  }
}

