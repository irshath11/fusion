class OfficialEmployeeRecord {
  final String employeeId;
  final String fullName;
  final String photoAsset;
  final String email;
  final String designation;
  final String department;
  final List<String> aliases;

  const OfficialEmployeeRecord({
    required this.employeeId,
    required this.fullName,
    required this.photoAsset,
    required this.email,
    required this.designation,
    required this.department,
    this.aliases = const [],
  });
}

class EmployeeDirectoryHelper {
  /// Master enterprise directory of employees from official company records
  static const List<OfficialEmployeeRecord> masterDirectory = [
    // --- Fusion Neo Division ---
    OfficialEmployeeRecord(
      employeeId: 'N-1003',
      fullName: 'Muhammed Riyas Hussain Hussain Kasim',
      photoAsset: 'assets/images/employees/N-1003.png',
      email: 'riyas@gmail.com',
      designation: 'Technician',
      department: 'Neo',
      aliases: ['riyas', 'muhammed riyas', 'emp-riyas'],
    ),
    OfficialEmployeeRecord(
      employeeId: 'N-1004',
      fullName: 'Shabi Bismillah Bismillah',
      photoAsset: 'assets/images/employees/N-1004.png',
      email: 'shabi@gmail.com',
      designation: 'Technician',
      department: 'Neo',
      aliases: ['shabi', 'emp-shabi', 'emp-n-1004'],
    ),
    OfficialEmployeeRecord(
      employeeId: 'N-1005',
      fullName: 'Adham Bismilla Bismilla',
      photoAsset: 'assets/images/employees/N-1005.png',
      email: 'adham@gmail.com',
      designation: 'Technician',
      department: 'Neo',
      aliases: ['adham', 'emp-adham', 'emp-n-1005'],
    ),
    OfficialEmployeeRecord(
      employeeId: 'N-1006',
      fullName: 'Irshath Ahamed Shaik Allavudin Shaik Allavudin',
      photoAsset: 'assets/images/employees/N-1006.png',
      email: 'sr.irshath@gmail.com',
      designation: 'Managing Director',
      department: 'Neo',
      aliases: ['irshath', 'irshath ahamed'],
    ),
    OfficialEmployeeRecord(
      employeeId: 'N-1007',
      fullName: 'Saji Kumar Thankamani Thankamani',
      photoAsset: 'assets/images/employees/N-1007.png',
      email: 'saji@gmail.com',
      designation: 'Electrician',
      department: 'Neo',
      aliases: ['saji', 'saji kumar'],
    ),
    OfficialEmployeeRecord(
      employeeId: 'N-1008',
      fullName: 'Kajamohideen Samsudeen Samsudeen',
      photoAsset: 'assets/images/employees/N-1008.png',
      email: 'kaja@gmail.com',
      designation: 'ELV Technician',
      department: 'Neo',
      aliases: ['kaja', 'kaja mohideen', 'kajamohideen'],
    ),
    OfficialEmployeeRecord(
      employeeId: 'N-1009',
      fullName: 'Abdul Kabarkhan Abdul Gafoor Abdul Gafoor',
      photoAsset: 'assets/images/employees/N-1009.png',
      email: 'kabar@gmail.com',
      designation: 'Technician',
      department: 'Neo',
      aliases: ['kabar', 'kabar khan', 'abdul kabarkhan'],
    ),
    OfficialEmployeeRecord(
      employeeId: 'N-1010',
      fullName: 'Krishnan Mahavishnu Mahavishnu',
      photoAsset: 'assets/images/employees/N-1010.png',
      email: 'krishnan@gmail.com',
      designation: 'Technician',
      department: 'Neo',
      aliases: ['krishnan'],
    ),
    OfficialEmployeeRecord(
      employeeId: 'N-1011',
      fullName: 'Kuthoos Abthul Kani Abthul Kani',
      photoAsset: 'assets/images/employees/N-1011.png',
      email: 'kuththus@gmail.com',
      designation: 'Technician',
      department: 'Neo',
      aliases: ['kuththus', 'kuthoos'],
    ),
    OfficialEmployeeRecord(
      employeeId: 'N-1012',
      fullName: 'Javeedu Rahuman Hameed Sulthan Hameed Sulthan',
      photoAsset: 'assets/images/employees/N-1012.png',
      email: 'javeed@gmail.com',
      designation: 'Technician',
      department: 'Neo',
      aliases: ['javeed', 'javeedu', 'javeedu rahuman'],
    ),
    OfficialEmployeeRecord(
      employeeId: 'N-1013',
      fullName: 'Abhishek Sharma Aniruddh Sharma',
      photoAsset: 'assets/images/employees/N-1013.png',
      email: 'abishek@gmail.com',
      designation: 'A/C Technician',
      department: 'Neo',
      aliases: ['abishek', 'abhishek'],
    ),

    // --- Fusion Maintenance Division ---
    OfficialEmployeeRecord(
      employeeId: '1004',
      fullName: 'Mohammed Iburahim Baseer Ahamed',
      photoAsset: 'assets/images/employees/1004.png',
      email: 'ib@fusionmaint.com',
      designation: 'Operations Engineer',
      department: 'Fusion',
      aliases: ['mohammed ibrahim', 'ibrahim', 'ib'],
    ),
    OfficialEmployeeRecord(
      employeeId: '1008',
      fullName: 'Ibramsha Sathar Sathar',
      photoAsset: 'assets/images/employees/1008.png',
      email: 'ibramsha@gmail.com',
      designation: 'Supervisor',
      department: 'Fusion',
      aliases: ['ibramsha'],
    ),
    OfficialEmployeeRecord(
      employeeId: '1012',
      fullName: 'Raja Mohammed Mohammed Ali',
      photoAsset: 'assets/images/employees/1012.png',
      email: 'raja@gmail.com',
      designation: 'Supervisor',
      department: 'Fusion',
      aliases: ['raja'],
    ),
    OfficialEmployeeRecord(
      employeeId: '1021',
      fullName: 'Mohamed Azarudheen Anvar Ali',
      photoAsset: 'assets/images/employees/1021.png',
      email: 'azar@gmail.com',
      designation: 'A/C Technician',
      department: 'Fusion',
      aliases: ['azar', 'azhar', 'azarudeen', 'azharudeen', 'mohamed azarudheen', 'mohamed azharudeen', 'emp-azar', 'emp-1021'],
    ),
    OfficialEmployeeRecord(
      employeeId: '1024',
      fullName: 'Ramesh Gopal Gopal',
      photoAsset: 'assets/images/employees/1024.png',
      email: 'ramesh@gmail.com',
      designation: 'Plumber',
      department: 'Fusion',
      aliases: ['ramesh'],
    ),
    OfficialEmployeeRecord(
      employeeId: '1031',
      fullName: 'Mohamed Rifaye Abdul Jabar Abdul Jabar',
      photoAsset: 'assets/images/employees/1031.png',
      email: 'rifaye@gmail.com',
      designation: 'A/C Technician',
      department: 'Fusion',
      aliases: ['rifaye', 'mohamed rifaye'],
    ),
    OfficialEmployeeRecord(
      employeeId: '1036',
      fullName: 'Mahatheer Mohamed Jamal Mohamed Jamal Mohamed',
      photoAsset: 'assets/images/employees/1036.png',
      email: 'mahatheer@gmail.com',
      designation: 'Coordinator',
      department: 'Fusion',
      aliases: ['mahatheer', 'mohamed jamal'],
    ),
    OfficialEmployeeRecord(
      employeeId: '1038',
      fullName: 'Mohamed Ali Shaik Mohamed Mohamed Ali',
      photoAsset: 'assets/images/employees/1038.png',
      email: 'shaik@gmail.com',
      designation: 'Technician',
      department: 'Fusion',
      aliases: ['shaik', 'mohamed ali shaik'],
    ),
    OfficialEmployeeRecord(
      employeeId: '1047',
      fullName: 'Ramakrishnan Kulangaravalappil Kuttan',
      photoAsset: 'assets/images/employees/1047.png',
      email: 'rama@gmail.com',
      designation: 'Painter',
      department: 'Fusion',
      aliases: ['rama', 'ramakrishnan'],
    ),
    OfficialEmployeeRecord(
      employeeId: '1048',
      fullName: 'Muhammad Irfan Faqeer Hussain',
      photoAsset: 'assets/images/employees/1048.png',
      email: 'irfan@gmail.com',
      designation: 'Painter',
      department: 'Fusion',
      aliases: ['irfan', 'muhammad irfan'],
    ),
    OfficialEmployeeRecord(
      employeeId: '1049',
      fullName: 'Sanjay Kumar Shrawan Kumar',
      photoAsset: 'assets/images/employees/1049.png',
      email: 'sanjay@gmail.com',
      designation: 'Mason',
      department: 'Fusion',
      aliases: ['sanjay', 'sanjay kumar'],
    ),
    OfficialEmployeeRecord(
      employeeId: '1054',
      fullName: 'Nowfal Rizwan Naina Mohamed Naina Mohamed',
      photoAsset: 'assets/images/employees/1054.png',
      email: 'nowfal@gmail.com',
      designation: 'Helper',
      department: 'Fusion',
      aliases: ['nowfal'],
    ),
    OfficialEmployeeRecord(
      employeeId: '1056',
      fullName: 'Rafi Ullah Khan Aman Ullah Khan',
      photoAsset: 'assets/images/employees/1056.png',
      email: 'rafi@gmail.com',
      designation: 'Driver',
      department: 'Fusion',
      aliases: ['rafi', 'rafi ullah', 'rafiullah', 'rafi ullah khan', 'emp-rafi', 'emp-1056'],
    ),
    OfficialEmployeeRecord(
      employeeId: '1057',
      fullName: 'Anandh Veeramani Veeramani',
      photoAsset: 'assets/images/employees/1057.png',
      email: 'anand@gmail.com',
      designation: 'Technician',
      department: 'Fusion',
      aliases: ['anand', 'anandh', 'anandh veeramani', 'anand veeramani', 'emp-anan', 'emp-ana', 'emp-1057'],
    ),
    OfficialEmployeeRecord(
      employeeId: '1058',
      fullName: 'Alnaser Samsudeen',
      photoAsset: 'assets/images/employees/1058.png',
      email: 'naser@gmail.com',
      designation: 'Technician',
      department: 'Fusion',
      aliases: ['naser', 'al naser', 'alnaser'],
    ),
    OfficialEmployeeRecord(
      employeeId: '1059',
      fullName: 'Saleem Allapitchai Allapitchai',
      photoAsset: 'assets/images/employees/1059.png',
      email: 'saleem@gmail.com',
      designation: 'Helper',
      department: 'Fusion',
      aliases: ['saleem'],
    ),
    OfficialEmployeeRecord(
      employeeId: '1060',
      fullName: 'Silambarasan Rajamanikkam Rajamanikkam',
      photoAsset: 'assets/images/employees/1060.png',
      email: 'silambu@gmail.com',
      designation: 'Mason',
      department: 'Fusion',
      aliases: ['silambu', 'silambarasan'],
    ),
  ];

  /// Find matching official record by employeeId, email, or full/short name
  static OfficialEmployeeRecord? resolveOfficialRecord({
    String? code,
    String? name,
    String? email,
    String? id,
  }) {
    final cleanCode = (code ?? '').trim().toUpperCase();
    final cleanEmail = (email ?? '').trim().toLowerCase();
    final cleanName = (name ?? '').trim().toLowerCase();
    final cleanId = (id ?? '').trim().toLowerCase();

    // 1. Direct exact Email match (100% unique across all company staff)
    if (cleanEmail.isNotEmpty) {
      for (final rec in masterDirectory) {
        if (rec.email.toLowerCase() == cleanEmail) {
          return rec;
        }
      }
    }

    // 2. Direct exact Employee Code / ID match
    if (cleanCode.isNotEmpty && cleanCode != 'EMP-000') {
      final codeNorm = cleanCode.replaceFirst('EMP-', '');
      for (final rec in masterDirectory) {
        if (rec.employeeId.toUpperCase() == cleanCode ||
            rec.employeeId.toUpperCase() == codeNorm) {
          return rec;
        }
      }
    }

    // 3. Direct exact full name match
    if (cleanName.isNotEmpty) {
      for (final rec in masterDirectory) {
        if (rec.fullName.trim().toLowerCase() == cleanName) {
          return rec;
        }
      }
    }

    // 4. Exact match against known aliases
    for (final rec in masterDirectory) {
      for (final alias in rec.aliases) {
        final a = alias.trim().toLowerCase();
        if (cleanName == a || cleanCode == a.toUpperCase() || cleanId == a) {
          return rec;
        }
      }
    }

    // Direct id match like 'emp-1057' or 'emp-n-1004'
    if (cleanId.isNotEmpty) {
      final idNorm = cleanId.replaceFirst('emp-', '');
      for (final rec in masterDirectory) {
        if (rec.employeeId.toLowerCase() == cleanId ||
            rec.employeeId.toLowerCase() == idNorm) {
          return rec;
        }
      }
    }

    return null;
  }

  /// Checks if an attendance record matches a target employee identity.
  /// Consolidates previous short names into official full names.
  static bool matchesEmployeeIdentity({
    required String recordEmployeeId,
    required String recordEmployeeName,
    String? employeeId,
    String? employeeCode,
    String? employeeName,
    String? employeeEmail,
  }) {
    final rId = recordEmployeeId.trim().toLowerCase();
    final rName = recordEmployeeName.trim().toLowerCase();
    final tId = (employeeId ?? '').trim().toLowerCase();
    final tCode = (employeeCode ?? '').trim().toLowerCase();
    final tName = (employeeName ?? '').trim().toLowerCase();
    final tEmail = (employeeEmail ?? '').trim().toLowerCase();

    // 1. Direct exact ID match
    if (tId.isNotEmpty && rId.isNotEmpty && rId == tId) return true;

    // 2. Direct exact Employee Code match
    if (tCode.isNotEmpty && rId.isNotEmpty && (rId == tCode || rId == 'emp-$tCode')) return true;

    // 3. Direct exact Name match
    if (tName.isNotEmpty && rName.isNotEmpty && rName == tName) return true;

    // 4. Resolve official records for target and record
    final targetOfficial = resolveOfficialRecord(
      code: tCode,
      name: tName,
      email: tEmail,
      id: tId,
    );

    if (targetOfficial != null) {
      final oName = targetOfficial.fullName.toLowerCase();
      final oCode = targetOfficial.employeeId.toLowerCase();

      if (rName == oName) return true;
      if (rId == oCode || rId == 'emp-$oCode') return true;

      for (final alias in targetOfficial.aliases) {
        final a = alias.toLowerCase();
        if (rName == a || rId == a || rId == 'emp-$a') return true;
      }
    }

    // Also check if record itself resolves to an official record that matches target
    final recordOfficial = resolveOfficialRecord(
      code: rId,
      name: rName,
      id: rId,
    );
    if (recordOfficial != null && targetOfficial != null) {
      if (recordOfficial.employeeId == targetOfficial.employeeId) return true;
    }

    return false;
  }

  /// Get the complete full name for an employee (falling back to provided name)
  static String getCompleteFullName({
    required String currentName,
    String? email,
    String? code,
    String? id,
  }) {
    final official = resolveOfficialRecord(
      code: code,
      name: currentName,
      email: email,
      id: id,
    );
    if (official != null) {
      return official.fullName;
    }
    return currentName.trim();
  }

  /// Get the official employee ID (e.g. "N-1003" or "1004")
  static String getEmployeeId({
    String? currentCode,
    String? name,
    String? email,
    String? id,
  }) {
    final official = resolveOfficialRecord(
      code: currentCode,
      name: name,
      email: email,
      id: id,
    );
    if (official != null) {
      return official.employeeId;
    }

    if (currentCode != null &&
        currentCode.trim().isNotEmpty &&
        currentCode.trim() != 'EMP-000') {
      return currentCode.trim();
    }

    final cleanName = (name ?? '').replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    if (cleanName.isNotEmpty) {
      final prefix = cleanName.length >= 4 ? cleanName.substring(0, 4) : cleanName;
      return 'EMP-$prefix';
    }

    if (id != null && id.length >= 4) {
      return 'EMP-${id.substring(0, 4).toUpperCase()}';
    }

    return 'EMP-001';
  }

  /// Resolves the photo to display (custom attached photo or official directory asset photo)
  static String? resolvePhoto({
    String? customPhotoUrl,
    String? employeeCode,
    String? fullName,
    String? email,
    String? id,
  }) {
    if (customPhotoUrl != null &&
        customPhotoUrl.trim().isNotEmpty &&
        (customPhotoUrl.startsWith('data:image') ||
            customPhotoUrl.startsWith('http') ||
            customPhotoUrl.startsWith('assets/') ||
            customPhotoUrl.startsWith('/'))) {
      return customPhotoUrl.trim();
    }

    final official = resolveOfficialRecord(
      code: employeeCode,
      name: fullName,
      email: email,
      id: id,
    );
    if (official != null) {
      return official.photoAsset;
    }

    // Direct exact employee code match for photo asset display
    final cleanCode = (employeeCode ?? '').trim().toUpperCase().replaceFirst('EMP-', '');
    if (cleanCode.isNotEmpty && cleanCode != '000') {
      for (final rec in masterDirectory) {
        if (rec.employeeId.toUpperCase() == cleanCode) {
          return rec.photoAsset;
        }
      }
    }

    if (customPhotoUrl != null && customPhotoUrl.trim().isNotEmpty) {
      return customPhotoUrl.trim();
    }

    return null;
  }
}
