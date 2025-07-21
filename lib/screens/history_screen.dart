import 'package:flutter/material.dart';
import 'package:uyg/services/db_service.dart';
import 'package:uyg/models/measurement.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Measurement> _allMeasurements = [];
  List<Measurement> _filteredMeasurements = [];
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final data = await DBService.getAllMeasurements();
    setState(() {
      _allMeasurements = data;
      _filteredMeasurements = data;
    });
  }

  void _filterByDate(DateTime date) {
    setState(() {
      _selectedDate = date;
      _filteredMeasurements =
          _allMeasurements.where((m) {
            final mDate = DateTime.parse(m.timestamp);
            return mDate.year == date.year &&
                mDate.month == date.month &&
                mDate.day == date.day;
          }).toList();
    });
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      _filterByDate(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.indigo[900],
      appBar: AppBar(
        title: const Text("Geçmiş Ölçümler"),
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _selectDate,
            tooltip: "Tarihe Göre Filtrele",
          ),
        ],
      ),
      body:
          _filteredMeasurements.isEmpty
              ? const Center(
                child: Text(
                  "Hiç ölçüm bulunamadı",
                  style: TextStyle(color: Colors.white70),
                ),
              )
              : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _filteredMeasurements.length,
                itemBuilder: (context, index) {
                  final m = _filteredMeasurements[index];
                  final dt = DateTime.parse(m.timestamp);
                  final formatted = DateFormat(
                    'yyyy-MM-dd – HH:mm:ss',
                  ).format(dt);

                  return Card(
                    color: Colors.white10,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      leading: const Icon(
                        Icons.favorite,
                        color: Colors.redAccent,
                      ),
                      title: Text(
                        "${m.bpm} BPM",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      subtitle: Text(
                        formatted,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  );
                },
              ),
    );
  }
}
