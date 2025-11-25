import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_datetime_picker_plus/flutter_datetime_picker_plus.dart';

class TodoPage extends StatefulWidget {
  const TodoPage({super.key});

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  int _selectedIndex = 1;
  final user = FirebaseAuth.instance.currentUser;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  String _selectedPriority = 'Sedang';

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    switch (index) {
      case 0:
        Navigator.pushNamed(context, '/home');
        break;
      case 1:
        // Sudah di To-Do List
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

  // ========================= GET TASKS STREAM ==========================
  Stream<QuerySnapshot> _getTasksStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('tasks')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // ========================= ADD OR EDIT TASK ==========================
  void _showTaskDialog({String? taskId, Map<String, dynamic>? existingData}) {
    if (existingData != null) {
      _titleController.text = existingData['title'] ?? '';
      _subjectController.text = existingData['subject'] ?? '';
      _timeController.text = existingData['time']?.toDate().toString() ?? '';
      _selectedPriority = existingData['priority'] ?? 'Sedang';
    } else {
      _titleController.clear();
      _subjectController.clear();
      _timeController.clear();
      _selectedPriority = 'Sedang';
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(taskId == null ? "Tambah Tugas" : "Edit Tugas"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: "Judul Tugas",
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                TextField(
                  controller: _subjectController,
                  decoration: const InputDecoration(
                    labelText: "Mata Pelajaran",
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                TextField(
                  controller: _timeController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: "Waktu Deadline",
                    hintText: "Pilih waktu",
                    border: OutlineInputBorder(),
                  ),
                  onTap: () {
                    DatePicker.showDateTimePicker(
                      context,
                      showTitleActions: true,
                      onConfirm: (date) {
                        _timeController.text = date.toString();
                      },
                      currentTime: DateTime.now(),
                      locale: LocaleType.id,
                    );
                  },
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                DropdownButtonFormField<String>(
                  value: _selectedPriority,
                  decoration: const InputDecoration(
                    labelText: "Prioritas",
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Tinggi', child: Text('Tinggi')),
                    DropdownMenuItem(value: 'Sedang', child: Text('Sedang')),
                    DropdownMenuItem(value: 'Rendah', child: Text('Rendah')),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedPriority = value!);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Batal"),
            ),
            ElevatedButton(
              style: Theme.of(context).elevatedButtonTheme.style,
              onPressed: () async {
                final title = _titleController.text.trim();
                final subject = _subjectController.text.trim();
                final time = _timeController.text.trim();

                if (title.isEmpty || time.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Judul dan waktu wajib diisi"),
                    ),
                  );
                  return;
                }

                final data = {
                  'title': title,
                  'subject': subject,
                  'time': Timestamp.fromDate(DateTime.parse(time)),
                  'priority': _selectedPriority,
                  'isCompleted': existingData?['isCompleted'] ?? false,
                  'createdAt': DateTime.now(),
                };

                try {
                  final ref = FirebaseFirestore.instance
                      .collection('users')
                      .doc(user!.uid)
                      .collection('tasks');
                  if (taskId == null) {
                    await ref.add(data);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Tugas berhasil ditambahkan 🎉"),
                        ),
                      );
                    }
                  } else {
                    await ref.doc(taskId).update(data);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Tugas berhasil diperbarui"),
                        ),
                      );
                    }
                  }
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Gagal menyimpan tugas: $e")),
                    );
                  }
                }
              },
              child: Text(taskId == null ? "Simpan" : "Perbarui"),
            ),
          ],
        );
      },
    );
  }

  // ========================= DELETE TASK ==========================
  void _deleteTask(String taskId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hapus Tugas"),
        content: const Text("Apakah Anda yakin ingin menghapus tugas ini?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Hapus"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('tasks')
            .doc(taskId)
            .delete();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Tugas berhasil dihapus")),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Gagal menghapus tugas: $e")));
        }
      }
    }
  }

  // ========================= FORMAT TIME ==========================
  String _formatTime(dynamic timeData) {
    if (timeData is Timestamp) {
      final date = timeData.toDate();
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'Mei',
        'Jun',
        'Jul',
        'Agu',
        'Sep',
        'Okt',
        'Nov',
        'Des',
      ];
      return '${date.day} ${months[date.month - 1]}, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (timeData is String) {
      return timeData;
    } else {
      return '-';
    }
  }

  // ========================= GET PRIORITY COLOR ==========================
  Color _getPriorityColor(String priority, bool isCompleted) {
    if (isCompleted) return Colors.grey;
    switch (priority) {
      case 'Tinggi':
        return Colors.redAccent;
      case 'Sedang':
        return Colors.orange;
      case 'Rendah':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  // ========================= BUILD UI ==========================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          "LearnTrack",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [IconButton(icon: const Icon(Icons.menu), onPressed: () {})],
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: _getTasksStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                "Gagal memuat tugas",
                style: TextStyle(color: Colors.red, fontSize: 16),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.checklist_rtl_rounded,
                    size: 80,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Semua tugas selesai! Saatnya istirahat.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final tasks = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final data = tasks[index].data() as Map<String, dynamic>;
              final taskId = tasks[index].id;
              final isCompleted = data['isCompleted'] ?? false;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border(
                    left: BorderSide(
                      color: _getPriorityColor(
                        data['priority'] ?? 'Sedang',
                        isCompleted,
                      ),
                      width: 4,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: Checkbox(
                    value: isCompleted,
                    activeColor: Theme.of(context).primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    onChanged: (val) async {
                      try {
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(user!.uid)
                            .collection('tasks')
                            .doc(taskId)
                            .update({'isCompleted': val});
                        if (context.mounted && val == true) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Tugas selesai! 🎉")),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Gagal memperbarui tugas: $e"),
                            ),
                          );
                        }
                      }
                    },
                  ),
                  title: Text(
                    data['title'] ?? '',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: isCompleted ? Colors.grey : Colors.black,
                      decoration: isCompleted
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      data['subject'] != null && data['subject'].isNotEmpty
                          ? '${data['subject']}, ${_formatTime(data['time'])}'
                          : _formatTime(data['time']),
                      style: TextStyle(
                        color: isCompleted ? Colors.grey : Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.edit_outlined,
                          color: Colors.blueAccent,
                          size: 20,
                        ),
                        tooltip: 'Edit',
                        onPressed: () =>
                            _showTaskDialog(taskId: taskId, existingData: data),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                          size: 20,
                        ),
                        tooltip: 'Hapus',
                        onPressed: () => _deleteTask(taskId),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF2196F3),
        onPressed: () => _showTaskDialog(),
        tooltip: 'Tambah Tugas Baru',
        child: const Icon(Icons.add, color: Colors.white),
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        elevation: 8,
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
