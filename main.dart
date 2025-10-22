// تطبيق Flutter بسيط لحساب المداخيل - واجهة عربية
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';

class Entry {
  String id;
  String title;
  double amount;
  DateTime date;
  Entry({required this.id, required this.title, required this.amount, required this.date});
  factory Entry.fromJson(Map<String, dynamic> j) => Entry(
    id: j['id'],
    title: j['title'],
    amount: (j['amount'] as num).toDouble(),
    date: DateTime.parse(j['date']),
  );
  Map<String,dynamic> toJson() => {'id':id,'title':title,'amount':amount,'date':date.toIso8601String()};
}

class Repo {
  static const key = 'income_app_entries_v1';
  final SharedPreferences prefs;
  Repo(this.prefs);
  List<Entry> loadAll() {
    final raw = prefs.getString(key);
    if (raw == null) return [];
    final decoded = jsonDecode(raw) as List;
    return decoded.map((e)=>Entry.fromJson(e)).toList();
  }
  Future<void> saveAll(List<Entry> entries) async {
    final encoded = jsonEncode(entries.map((e)=>e.toJson()).toList());
    await prefs.setString(key, encoded);
  }
}

class AppState extends ChangeNotifier {
  final Repo repo;
  List<Entry> _entries = [];
  AppState(this.repo) { _entries = repo.loadAll(); }
  List<Entry> get entries => List.unmodifiable(_entries);
  double get total => _entries.fold(0.0,(p,e)=>p+e.amount);
  Future<void> add(Entry e) async { _entries.add(e); await repo.saveAll(_entries); notifyListeners(); }
  Future<void> remove(String id) async { _entries.removeWhere((e)=>e.id==id); await repo.saveAll(_entries); notifyListeners(); }
  Future<File> exportCsv() async {
    final rows = [['id','title','amount','date']];
    for(var e in _entries) rows.add([e.id,e.title,e.amount.toString(),e.date.toIso8601String()]);
    final csv = const ListToCsvConverter().convert(rows);
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/income_export_${DateTime.now().millisecondsSinceEpoch}.csv');
    await file.writeAsString(csv);
    return file;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final repo = Repo(prefs);
  runApp(ChangeNotifierProvider(create: (_)=>AppState(repo), child: const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}): super(key:key);
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'حساب المداخيل',
      theme: ThemeData(primarySwatch: Colors.teal, useMaterial3:true),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget { const HomePage({Key? key}): super(key:key); @override State<HomePage> createState()=>_HomePageState(); }
class _HomePageState extends State<HomePage> {
  final _title = TextEditingController();
  final _amount = TextEditingController();
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('حساب المداخيل')),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(controller: _title, decoration: const InputDecoration(labelText: 'البيان')),
              const SizedBox(height:8),
              TextField(controller: _amount, keyboardType: TextInputType.numberWithOptions(decimal:true), decoration: const InputDecoration(labelText: 'المبلغ')),
              const SizedBox(height:12),
              ElevatedButton(onPressed: () async {
                final t = _title.text.trim();
                final a = double.tryParse(_amount.text.replaceAll(',', '.'));
                if(t.isEmpty || a==null || a<=0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء إدخال بيان ومبلغ صالح')));
                  return;
                }
                final e = Entry(id: DateTime.now().millisecondsSinceEpoch.toString(), title: t, amount: a, date: DateTime.now());
                await app.add(e);
                _title.clear(); _amount.clear();
              }, child: const Text('إضافة')),
              const SizedBox(height:20),
              const Text('القائمة', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height:8),
              Expanded(child: ListView.separated(
                itemCount: app.entries.length,
                separatorBuilder: (_,__)=>const Divider(),
                itemBuilder: (c,i){
                  final e = app.entries.reversed.toList()[i];
                  return ListTile(
                    title: Text(e.title),
                    subtitle: Text(e.date.toLocal().toString()),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(e.amount.toStringAsFixed(2)),
                      IconButton(icon: const Icon(Icons.delete), onPressed: () async { await app.remove(e.id); })
                    ]),
                  );
                }
              )),
              const SizedBox(height:8),
              Text('المجموع الكلي: ' + app.total.toStringAsFixed(2), style: const TextStyle(fontSize:18, fontWeight: FontWeight.bold)),
              const SizedBox(height:8),
              ElevatedButton(onPressed: () async {
                final f = await app.exportCsv();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم التصدير إلى: ${f.path}')));
              }, child: const Text('تصدير CSV')),
            ],
          ),
        ),
      ),
    );
  }
}