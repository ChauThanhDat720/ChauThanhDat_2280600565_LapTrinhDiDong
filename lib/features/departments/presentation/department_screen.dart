import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../doctors/presentation/doctor_screens.dart';
import '../domain/department.dart';

class DepartmentScreen extends StatefulWidget {
  const DepartmentScreen({super.key});

  @override
  State<DepartmentScreen> createState() => _DepartmentScreenState();
}

class _DepartmentScreenState extends State<DepartmentScreen> {
  String _query = '';

  List<Department> get _filteredDepartments {
    final query = _query.trim().toLowerCase();

    if (query.isEmpty) {
      return departments;
    }

    return departments.where((department) {
      return department.name.toLowerCase().contains(query) ||
          department.description.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = _filteredDepartments;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Departments',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Text(
              'Find the right specialist',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Choose a department to explore our doctors and services.',
              style: TextStyle(color: AppColors.mutedText, height: 1.4),
            ),
            const SizedBox(height: 20),

            // Search
            TextField(
              onChanged: (value) {
                setState(() {
                  _query = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search departments...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          setState(() {
                            _query = '';
                          });
                        },
                        icon: const Icon(Icons.clear),
                      ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),

            const SizedBox(height: 20),

            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 50),
                child: Column(
                  children: [
                    Icon(
                      Icons.search_off_rounded,
                      size: 55,
                      color: AppColors.mutedText,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'No departments found',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              )
            else
              ...items.map(
                (department) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _DepartmentCard(department: department),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DepartmentCard extends StatelessWidget {
  const _DepartmentCard({required this.department});

  final Department department;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                DoctorListScreen(initialDepartmentId: department.id),
          ),
        ),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF7F8),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  department.icon,
                  style: const TextStyle(fontSize: 25),
                ),
              ),
              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      department.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      department.description,
                      style: const TextStyle(
                        color: AppColors.mutedText,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '${department.doctorCount} doctors',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.mutedText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
