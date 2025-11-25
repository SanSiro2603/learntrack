import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String username = 'Pengguna';
  int totalJam = 0;
  int tugasSelesai = 0;
  double konsistensi = 0.0;
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _getUserData();
  }

  Future<void> _getUserData() async {
    try {
      setState(() => isLoading = true);
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Ambil data profil
        final profileDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        // Ambil data statistik harian
        final statsDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('stats')
            .doc(
              DateTime.now().toIso8601String().split('T')[0],
            ) // Berdasarkan tanggal hari ini
            .get();

        if (profileDoc.exists) {
          setState(() {
            username = profileDoc['username'] ?? 'Pengguna';
          });
        }

        if (statsDoc.exists) {
          setState(() {
            totalJam = statsDoc['totalJam'] ?? 0;
            tugasSelesai = statsDoc['tugasSelesai'] ?? 0;
            konsistensi = statsDoc['konsistensi']?.toDouble() ?? 0.0;
          });
        }
      }
    } catch (e) {
      setState(() => errorMessage = 'Gagal memuat data: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    switch (index) {
      case 0:
        // Sudah di Home, tidak perlu navigasi
        break;
      case 1:
        Navigator.pushNamed(context, '/todo');
        break;
      case 2:
        Navigator.pushNamed(context, '/tracker');
        break;
      case 3:
        Navigator.pushNamed(context, '/statistik');
        break;
      case 4:
        Navigator.pushNamed(context, '/profile');
        break;
    }
  }

  Widget _buildProgressBar(double konsistensi) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Konsistensi belajar",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              Row(
                children: [
                  Text(
                    "${(konsistensi * 100).toInt()}%",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF7C4DFF),
                    ),
                  ),
                  if (konsistensi > 0.8)
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(
                        Icons.star,
                        color: Colors.amber,
                        size: 20,
                        semanticLabel: 'Pencapaian konsistensi tinggi',
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: konsistensi,
              minHeight: 10,
              backgroundColor: Colors.grey[300],
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF7C4DFF),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(
              child: Text(
                errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            )
          : SafeArea(
              child: Padding(
                padding: EdgeInsets.all(
                  MediaQuery.of(context).size.width * 0.05,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 🔹 Salam pembuka
                    Text(
                      "Halo, $username",
                      style: TextStyle(
                        fontSize: MediaQuery.of(context).size.width * 0.06,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 🔹 Kartu ringkasan belajar
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEAE4FF),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.all(12),
                                child: const Icon(
                                  Icons.menu_book_rounded,
                                  color: Color(0xFF7C4DFF),
                                  size: 30,
                                  semanticLabel: 'Ikon buku belajar',
                                ),
                              ),
                              const SizedBox(width: 15),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Total jam belajar hari ini",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    "$totalJam jam",
                                    style: const TextStyle(
                                      color: Color(0xFF7C4DFF),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    "Jumlah tugas selesai: $tugasSelesai",
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          ElevatedButton(
                            onPressed: () =>
                                Navigator.pushNamed(context, '/tracker'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7C4DFF),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text("Lanjut"),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 25),

                    // 🔹 Progress Konsistensi Belajar
                    _buildProgressBar(konsistensi),
                  ],
                ),
              ),
            ),

      // 🔹 Bottom Navigation
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: const Color(0xFF7C4DFF),
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
            tooltip: 'Beranda',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.checklist_rtl_rounded),
            label: 'To-Do',
            tooltip: 'Daftar Tugas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.timer_rounded),
            label: 'Tracker',
            tooltip: 'Pelacak Belajar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_rounded),
            label: 'Statistik',
            tooltip: 'Statistik Belajar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profil',
            tooltip: 'Profil Pengguna',
          ),
        ],
      ),
    );
  }
}
