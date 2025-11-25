import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class TrackerPage extends StatefulWidget {
  const TrackerPage({super.key});

  @override
  State<TrackerPage> createState() => _TrackerPageState();
}

class _TrackerPageState extends State<TrackerPage> {
  // State Variables
  int _selectedIndex = 2;
  final User? _user = FirebaseAuth.instance.currentUser;

  // Timer State
  Timer? _timer;
  int _seconds = 0;
  bool _isRunning = false;
  DateTime? _sessionStartTime;

  // Subject State
  String _selectedSubject = '';
  List<String> _availableSubjects = [];
  Map<String, int> _subjectTimers = {};
  final TextEditingController _newSubjectController = TextEditingController();

  // Target Time State & Controllers
  int _targetSeconds = 0;
  final TextEditingController _hoursController = TextEditingController();
  final TextEditingController _minutesController = TextEditingController();
  final TextEditingController _secondsController = TextEditingController();

  // Lifecycle Methods
  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _hoursController.dispose();
    _minutesController.dispose();
    _secondsController.dispose();
    _newSubjectController.dispose();
    super.dispose();
  }

  // Data Operations
  Future<void> _loadInitialData() async {
    await Future.wait([_loadSubjects(), _loadSubjectTimers()]);
  }

  Future<void> _loadSubjects() async {
    if (_user?.uid == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.uid)
          .collection('tasks')
          .get();

      final subjects = snapshot.docs
          .map((doc) => doc.data()['subject'] as String?)
          .where((subject) => subject != null && subject.isNotEmpty)
          .toSet();

      setState(() {
        _availableSubjects = subjects.cast<String>().toList()..sort();
        if (_availableSubjects.isNotEmpty && _selectedSubject.isEmpty) {
          _selectedSubject = _availableSubjects.first;
          _seconds = _subjectTimers[_selectedSubject] ?? 0;
        }
      });
    } catch (e) {
      debugPrint('Error loading subjects: $e');
      _showSnackBar('Gagal memuat mata pelajaran.', Colors.redAccent);
    }
  }

  Future<void> _loadSubjectTimers() async {
    if (_user?.uid == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.uid)
          .collection('tracker_data')
          .doc('current_timers')
          .get();

      if (doc.exists && doc.data() != null) {
        setState(() {
          _subjectTimers = Map<String, int>.from(doc.data()!);
          if (_selectedSubject.isNotEmpty) {
            _seconds = _subjectTimers[_selectedSubject] ?? 0;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading timers: $e');
      _showSnackBar('Gagal memuat data timer.', Colors.redAccent);
    }
  }

  Future<void> _saveCurrentTimer() async {
    if (_user?.uid == null || _selectedSubject.isEmpty) return;

    try {
      _subjectTimers[_selectedSubject] = _seconds;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.uid)
          .collection('tracker_data')
          .doc('current_timers')
          .set(_subjectTimers);
    } catch (e) {
      debugPrint('Error saving timer: $e');
    }
  }

  Future<void> _saveSession() async {
    if (_user?.uid == null || _seconds < 60) {
      _showSnackBar(
        "Sesi belajar minimal 1 menit untuk disimpan.",
        Colors.orange,
      );
      return;
    }

    final endTime = DateTime.now();
    final startTime =
        _sessionStartTime ?? endTime.subtract(Duration(seconds: _seconds));

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.uid)
          .collection('study_sessions')
          .add({
            'subject': _selectedSubject,
            'duration': _seconds,
            'targetDuration': _targetSeconds,
            'isTargetReached': _targetSeconds > 0 && _seconds >= _targetSeconds,
            'startTime': Timestamp.fromDate(startTime),
            'endTime': Timestamp.fromDate(endTime),
            'date': Timestamp.now(),
          });

      setState(() {
        _subjectTimers[_selectedSubject] = 0;
        _seconds = 0;
        _targetSeconds = 0;
        _clearTargetControllers();
      });
      await _saveCurrentTimer();
      _showSnackBar(
        "Sesi disimpan: ${_formatShortDuration(_seconds)} 🎉",
        Colors.green,
      );
    } catch (e) {
      debugPrint('Error saving session: $e');
      _showSnackBar("Gagal menyimpan sesi: $e", Colors.redAccent);
    }
  }

  Future<void> _addNewSubject() async {
    final newSubject = _newSubjectController.text.trim();
    if (newSubject.isEmpty) {
      _showSnackBar("Masukkan nama mata pelajaran.", Colors.orange);
      return;
    }

    if (_availableSubjects.contains(newSubject)) {
      _showSnackBar("Mata pelajaran sudah ada.", Colors.orange);
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.uid)
          .collection('tasks')
          .add({'subject': newSubject, 'createdAt': Timestamp.now()});

      setState(() {
        _availableSubjects.add(newSubject);
        _availableSubjects.sort();
        _selectedSubject = newSubject;
        _seconds = _subjectTimers[newSubject] ?? 0;
        _newSubjectController.clear();
      });
      _showSnackBar("Mata pelajaran $newSubject ditambahkan.", Colors.green);
    } catch (e) {
      debugPrint('Error adding subject: $e');
      _showSnackBar("Gagal menambahkan mata pelajaran.", Colors.redAccent);
    }
  }

  // Timer Operations
  void _startTimer() {
    if (_selectedSubject.isEmpty) {
      _showSnackBar(
        "Pilih atau tambahkan mata pelajaran terlebih dahulu.",
        Colors.orange,
      );
      return;
    }

    setState(() {
      _isRunning = true;
      _sessionStartTime = DateTime.now();
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _seconds++);

      if (_targetSeconds > 0 && _seconds >= _targetSeconds) {
        _stopTimer();
        _saveSession();
        _showSnackBar(
          "🎉 Target waktu tercapai! Sesi belajar disimpan.",
          Colors.green,
        );
      }

      if (_seconds % 15 == 0) {
        _saveCurrentTimer();
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    setState(() => _isRunning = false);
    _saveCurrentTimer();
  }

  Future<void> _resetTimer() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Reset Timer"),
        content: Text(
          "Reset timer untuk $_selectedSubject? Waktu saat ini: ${_formatDuration(_seconds)}",
        ),
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
            child: const Text("Reset"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _timer?.cancel();
      setState(() {
        _isRunning = false;
        _seconds = 0;
        _subjectTimers[_selectedSubject] = 0;
      });
      await _saveCurrentTimer();
      _showSnackBar("Timer berhasil direset.", Colors.blue);
    }
  }

  // UI Handlers
  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    const routes = {0: '/home', 1: '/todo', 3: '/statistik', 4: '/profile'};
    if (routes.containsKey(index)) {
      Navigator.pushNamed(context, routes[index]!);
    }
  }

  void _changeSubject(String newSubject) {
    if (_isRunning) {
      _showSnackBar("Stop timer sebelum ganti mata pelajaran.", Colors.orange);
      return;
    }

    if (_selectedSubject.isNotEmpty) {
      _subjectTimers[_selectedSubject] = _seconds;
      _saveCurrentTimer();
    }

    setState(() {
      _selectedSubject = newSubject;
      _seconds = _subjectTimers[newSubject] ?? 0;
    });
  }

  void _updateTargetSeconds() {
    final hours = int.tryParse(_hoursController.text) ?? 0;
    final minutes = int.tryParse(_minutesController.text) ?? 0;
    final seconds = int.tryParse(_secondsController.text) ?? 0;
    setState(() {
      _targetSeconds = (hours * 3600) + (minutes * 60) + seconds;
    });
  }

  void _setQuickTime(int minutes) {
    setState(() {
      _hoursController.clear();
      _minutesController.text = minutes.toString();
      _secondsController.clear();
      _targetSeconds = minutes * 60;
    });
  }

  void _clearTargetControllers() {
    _hoursController.clear();
    _minutesController.clear();
    _secondsController.clear();
  }

  void _showSnackBar(String message, Color backgroundColor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: backgroundColor),
    );
  }

  // Formatters
  String _formatDuration(int totalSeconds) {
    final duration = Duration(seconds: totalSeconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return hours > 0
        ? '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}'
        : '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatShortDuration(int totalSeconds) {
    if (totalSeconds < 60) return '$totalSeconds detik';
    final duration = Duration(seconds: totalSeconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return hours > 0 ? '$hours jam $minutes menit' : '$minutes menit';
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }

  // UI Components
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(title: const Text('Tracker Belajar'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Column(
          children: [
            _buildTimerDisplay(),
            const SizedBox(height: 24),
            if (!_isRunning) _buildTargetInputCard(),
            const SizedBox(height: 16),
            _buildSubjectSelectorCard(),
            const SizedBox(height: 24),
            _buildControlButtons(),
            const SizedBox(height: 32),
            _buildStudyHistory(),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'To-Do'),
          BottomNavigationBarItem(icon: Icon(Icons.timer), label: 'Tracker'),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Statistik',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildTimerDisplay() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 240,
          height: 240,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                spreadRadius: 5,
              ),
            ],
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _formatDuration(_seconds),
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isRunning
                  ? 'Sedang Belajar...'
                  : (_targetSeconds > 0
                        ? 'Target: ${_formatDuration(_targetSeconds)}'
                        : 'Waktu Belajar'),
              style: TextStyle(
                fontSize: 14,
                color: _isRunning
                    ? Theme.of(context).primaryColor
                    : Colors.grey,
                fontWeight: _isRunning ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (_targetSeconds > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SizedBox(
                  width: 200,
                  child: LinearProgressIndicator(
                    value: _seconds / _targetSeconds.clamp(1, double.infinity),
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).primaryColor,
                    ),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildTargetInputCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Card(
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Target Waktu (Opsional)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildTimeInput('Jam', _hoursController),
                  const SizedBox(width: 8),
                  _buildTimeInput('Menit', _minutesController),
                  const SizedBox(width: 8),
                  _buildTimeInput('Detik', _secondsController),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _quickTimeButton(15),
                  _quickTimeButton(25),
                  _quickTimeButton(45),
                  _quickTimeButton(60),
                ],
              ),
              if (_targetSeconds > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Target diset: ${_formatDuration(_targetSeconds)}',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeInput(String label, TextEditingController controller) {
    return Expanded(
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
        onChanged: (_) => _updateTargetSeconds(),
      ),
    );
  }

  Widget _quickTimeButton(int minutes) {
    return OutlinedButton(
      onPressed: () => _setQuickTime(minutes),
      style: OutlinedButton.styleFrom(
        foregroundColor: Theme.of(context).primaryColor,
        side: BorderSide(color: Theme.of(context).primaryColor),
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      child: Text('$minutes\''),
    );
  }

  Widget _buildSubjectSelectorCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pilih atau Tambah Mata Pelajaran',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedSubject.isEmpty ? null : _selectedSubject,
                hint: const Text('Pilih mata pelajaran'),
                items: _availableSubjects
                    .map(
                      (subject) => DropdownMenuItem(
                        value: subject,
                        child: Text(subject),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) _changeSubject(value);
                },
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newSubjectController,
                      decoration: const InputDecoration(
                        hintText: 'Masukkan mata pelajaran baru',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _addNewSubject,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: const Text('Tambah'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!_isRunning)
            ElevatedButton(
              onPressed: _startTimer,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text('Mulai'),
            ),
          if (_isRunning) ...[
            ElevatedButton(
              onPressed: _stopTimer,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text('Pause'),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: _saveSession,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text('Selesai'),
            ),
          ],
          if (_seconds > 0 && !_isRunning)
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: IconButton(
                onPressed: _resetTimer,
                icon: const Icon(Icons.refresh, color: Colors.redAccent),
                tooltip: 'Reset Timer',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStudyHistory() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Riwayat Belajar',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(_user?.uid)
                .collection('study_sessions')
                .orderBy('date', descending: true)
                .limit(5)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text('Gagal memuat riwayat.');
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final sessions = snapshot.data?.docs ?? [];
              if (sessions.isEmpty) {
                return const Text('Belum ada riwayat belajar.');
              }
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sessions.length,
                itemBuilder: (context, index) {
                  final session =
                      sessions[index].data() as Map<String, dynamic>;
                  final subject = session['subject'] as String? ?? 'Unknown';
                  final duration = session['duration'] as int? ?? 0;
                  final date = (session['date'] as Timestamp?)?.toDate();
                  return ListTile(
                    title: Text(subject),
                    subtitle: Text(
                      'Durasi: ${_formatShortDuration(duration)} • ${date != null ? _formatDate(Timestamp.fromDate(date)) : 'Unknown'}',
                    ),
                    trailing: session['isTargetReached'] == true
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : null,
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
