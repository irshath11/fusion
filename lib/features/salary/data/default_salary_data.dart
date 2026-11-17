import '../domain/employee_salary_config.dart';

/// Pre-populated company employee salary records directly transcribed from
/// official organizational salary registers (Fusion Maintenance Division & Fusion Neo Division).
class DefaultSalaryData {
  static List<EmployeeSalaryConfig> get defaultConfigs => [
        // =====================================================================
        // FUSION MAINTENANCE DIVISION
        // =====================================================================
        EmployeeSalaryConfig(
          employeeCode: '1004',
          employeeName: 'Mohammed Iburahim Baseer Ahamed',
          department: 'Fusion',
          fixedSalary: 2000.0,
          variableSalary: 4000.0, // 3800 + 200 allowance
          otIncludedInVariable: true,
        ),
        EmployeeSalaryConfig(
          employeeCode: '1008',
          employeeName: 'Ibramsha Sathar Sathar',
          department: 'Fusion',
          fixedSalary: 1500.0,
          variableSalary: 1500.0, // 1300 + 200 allowance
          otIncludedInVariable: true,
        ),
        EmployeeSalaryConfig(
          employeeCode: '1012',
          employeeName: 'Raja Mohammed Mohammed Ali',
          department: 'Fusion',
          fixedSalary: 1500.0,
          variableSalary: 1100.0,
        ),
        EmployeeSalaryConfig(
          employeeCode: '1021',
          employeeName: 'Mohamed Azarudheen Anvar Ali',
          department: 'Fusion',
          fixedSalary: 1000.0,
          variableSalary: 800.0,
        ),
        EmployeeSalaryConfig(
          employeeCode: '1024',
          employeeName: 'Ramesh Gopal Gopal',
          department: 'Fusion',
          fixedSalary: 1500.0,
          variableSalary: 500.0,
        ),
        EmployeeSalaryConfig(
          employeeCode: '1031',
          employeeName: 'Mohamed Rifaye Abdul Jabar Abdul Jabar',
          department: 'Fusion',
          fixedSalary: 1000.0,
          variableSalary: 500.0,
          otIncludedInVariable: true,
        ),
        EmployeeSalaryConfig(
          employeeCode: '1036',
          employeeName: 'Mahatheer Mohamed Jamal Mohamed Jamal Mohamed',
          department: 'Fusion',
          fixedSalary: 1500.0, // 1200 + 300 base
          variableSalary: 1500.0,
        ),
        EmployeeSalaryConfig(
          employeeCode: '1038',
          employeeName: 'Mohamed Ali Shaik Mohamed Mohamed Ali',
          department: 'Fusion',
          fixedSalary: 1500.0,
          variableSalary: 700.0,
        ),
        EmployeeSalaryConfig(
          employeeCode: '1047',
          employeeName: 'Ramakrishnan Kulangaravalappil Kuttan',
          department: 'Fusion',
          fixedSalary: 1200.0,
          variableSalary: 300.0,
        ),
        EmployeeSalaryConfig(
          employeeCode: '1048',
          employeeName: 'Muhammad Irfan Faqeer Hussain',
          department: 'Fusion',
          fixedSalary: 1200.0,
          variableSalary: 400.0,
        ),
        EmployeeSalaryConfig(
          employeeCode: '1049',
          employeeName: 'Sanjay Kumar Shrawan Kumar',
          department: 'Fusion',
          fixedSalary: 1200.0,
          variableSalary: 600.0,
        ),
        EmployeeSalaryConfig(
          employeeCode: '1054',
          employeeName: 'Nowfal Rizwan Naina Mohamed Naina Mohamed',
          department: 'Fusion',
          fixedSalary: 1000.0,
          variableSalary: 400.0,
        ),
        EmployeeSalaryConfig(
          employeeCode: '1056',
          employeeName: 'Rafi Ullah Khan Aman Ullah Khan',
          department: 'Fusion',
          fixedSalary: 1200.0,
          variableSalary: 600.0,
        ),
        EmployeeSalaryConfig(
          employeeCode: '1057',
          employeeName: 'Anandh Veeramani Veeramani',
          department: 'Fusion',
          fixedSalary: 1500.0,
          variableSalary: 1500.0, // 1000 + 500 allowance
          otIncludedInVariable: true,
        ),
        EmployeeSalaryConfig(
          employeeCode: '1058',
          employeeName: 'Alnaser Samsudeen',
          department: 'Fusion',
          fixedSalary: 2000.0,
          variableSalary: 4800.0,
        ),
        EmployeeSalaryConfig(
          employeeCode: '1059',
          employeeName: 'Saleem Allapitchai Allapitchai',
          department: 'Fusion',
          fixedSalary: 1200.0,
          variableSalary: 200.0,
        ),
        EmployeeSalaryConfig(
          employeeCode: '1060',
          employeeName: 'Silambarasan Rajamanikkam Rajamanikkam',
          department: 'Fusion',
          fixedSalary: 1000.0,
          variableSalary: 400.0,
        ),

        // =====================================================================
        // FUSION NEO DIVISION
        // =====================================================================
        EmployeeSalaryConfig(
          employeeCode: 'N-1003',
          employeeName: 'Muhammed Riyas Hussain Hussain Kasim',
          department: 'Neo',
          fixedSalary: 1200.0,
          variableSalary: 800.0,
          otIncludedInVariable: true,
        ),
        EmployeeSalaryConfig(
          employeeCode: 'N-1004',
          employeeName: 'Shabi Bismillah Bismillah',
          department: 'Neo',
          fixedSalary: 1200.0,
          variableSalary: 1100.0,
        ),
        EmployeeSalaryConfig(
          employeeCode: 'N-1005',
          employeeName: 'Adham Bismilla Bismilla',
          department: 'Neo',
          fixedSalary: 1200.0,
          variableSalary: 600.0,
        ),
        EmployeeSalaryConfig(
          employeeCode: 'N-1006',
          employeeName: 'Irshath Ahamed Shaik Allavudin Shaik Allavudin',
          department: 'Neo',
          fixedSalary: 1500.0,
          variableSalary: 2500.0,
          otIncludedInVariable: true,
        ),
        EmployeeSalaryConfig(
          employeeCode: 'N-1007',
          employeeName: 'Saji Kumar Thankamani Thankamani',
          department: 'Neo',
          fixedSalary: 1200.0,
          variableSalary: 600.0,
        ),
        EmployeeSalaryConfig(
          employeeCode: 'N-1008',
          employeeName: 'Kajamohideen Samsudeen Samsudeen',
          department: 'Neo',
          fixedSalary: 1200.0,
          variableSalary: 800.0,
        ),
        EmployeeSalaryConfig(
          employeeCode: 'N-1009',
          employeeName: 'Abdul Kabarkhan Abdul Gafoor Abdul Gafoor',
          department: 'Neo',
          fixedSalary: 1500.0,
          variableSalary: 1700.0,
          otIncludedInVariable: true,
        ),
        EmployeeSalaryConfig(
          employeeCode: 'N-1010',
          employeeName: 'Krishnan Mahavishnu Mahavishnu',
          department: 'Neo',
          fixedSalary: 1000.0,
          variableSalary: 700.0,
        ),
        EmployeeSalaryConfig(
          employeeCode: 'N-1011',
          employeeName: 'Kuthoos Abthul Kani Abthul Kani',
          department: 'Neo',
          fixedSalary: 1000.0,
          variableSalary: 600.0,
        ),
        EmployeeSalaryConfig(
          employeeCode: 'N-1012',
          employeeName: 'Javeedu Rahuman Hameed Sulthan Hameed Sulthan',
          department: 'Neo',
          fixedSalary: 1000.0,
          variableSalary: 300.0,
        ),
        EmployeeSalaryConfig(
          employeeCode: 'N-1013',
          employeeName: 'Abhishek Sharma Aniruddh Sharma',
          department: 'Neo',
          fixedSalary: 1200.0,
          variableSalary: 800.0,
        ),
        EmployeeSalaryConfig(
          employeeCode: 'N-1014',
          employeeName: 'Meeran',
          department: 'Neo',
          fixedSalary: 1500.0,
          variableSalary: 3500.0,
          otIncludedInVariable: true,
        ),
      ];
}

