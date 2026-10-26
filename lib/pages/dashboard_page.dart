import 'package:flutter/material.dart';

import 'recent_page.dart';

/// Shell cua man hinh chinh.
///
/// Truoc day day la bottom navigation 3 tab (Recent / Review / Settings).
/// Nay gop lai con 1 man hinh duy nhat:
/// - danh sach tu gan day (RecentPage)
/// - nut "On tap hom nay" o day man hinh (kem so tu den han) -> ReviewPage
/// - banh rang o header -> ProfilePage (Settings)
class DashboardPage extends StatelessWidget {
  final int userId;

  const DashboardPage({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return RecentPage(userId: userId);
  }
}
