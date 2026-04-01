import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:logbook_app_001/features/logbook/models/log_model.dart';

void main() {
  const boxName = 'modul3_test_box';

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_modul3_test_');
    Hive.init(tempDir.path);

    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(LogCategoryAdapter());
    }
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(LogModelAdapter());
    }
  });

  tearDown(() async {
    if (Hive.isBoxOpen(boxName)) {
      final box = Hive.box<LogModel>(boxName);
      await box.clear();
      await box.close();
    }
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('Module 3: save log to disk and read it back', () async {
    final box = await Hive.openBox<LogModel>(boxName);

    final log = LogModel(
      id: 'm3-local-001',
      title: 'Local Save Test',
      description: 'Menguji penyimpanan lokal Hive',
      date: DateTime.now().toIso8601String(),
      authorId: 'tester',
      teamId: 'team-local',
      category: LogCategory.other,
      isSynced: false,
      isPublic: false,
    );

    await box.add(log);

    expect(box.length, 1);

    final saved = box.getAt(0);
    expect(saved, isNotNull);
    expect(saved!.title, 'Local Save Test');
    expect(saved.isSynced, false);
  });

  test('Module 3: update local data on disk', () async {
    final box = await Hive.openBox<LogModel>(boxName);

    final original = LogModel(
      id: 'm3-local-002',
      title: 'Before Update',
      description: 'Desc lama',
      date: DateTime.now().toIso8601String(),
      authorId: 'tester',
      teamId: 'team-local',
      category: LogCategory.other,
      isSynced: false,
      isPublic: false,
    );

    await box.add(original);

    final updated = original.copyWith(
      title: 'After Update',
      description: 'Desc baru',
    );

    await box.putAt(0, updated);

    final result = box.getAt(0);
    expect(result, isNotNull);
    expect(result!.title, 'After Update');
    expect(result.description, 'Desc baru');
  });

  test('Module 3: delete local data from disk (removeLog)', () async {
    final box = await Hive.openBox<LogModel>(boxName);

    final log = LogModel(
      id: 'm3-local-003',
      title: 'To Delete',
      description: 'Will be deleted',
      date: DateTime.now().toIso8601String(),
      authorId: 'tester',
      teamId: 'team-local',
      category: LogCategory.other,
      isSynced: false,
      isPublic: false,
    );

    await box.add(log);
    expect(box.length, 1);

    await box.deleteAt(0);
    expect(box.length, 0);
  });

  test('Module 3: search log by title (searchLog)', () async {
    final box = await Hive.openBox<LogModel>(boxName);

    final logs = [
      LogModel(
        id: 'm3-search-001',
        title: 'Database Design',
        description: 'Mendesain struktur database',
        date: DateTime.now().toIso8601String(),
        authorId: 'tester',
        teamId: 'team-local',
        category: LogCategory.academic,
        isSynced: false,
        isPublic: false,
      ),
      LogModel(
        id: 'm3-search-002',
        title: 'API Development',
        description: 'Mengembangkan REST API',
        date: DateTime.now().toIso8601String(),
        authorId: 'tester',
        teamId: 'team-local',
        category: LogCategory.academic,
        isSynced: false,
        isPublic: false,
      ),
      LogModel(
        id: 'm3-search-003',
        title: 'UI Component',
        description: 'Membuat komponen UI reusable',
        date: DateTime.now().toIso8601String(),
        authorId: 'tester',
        teamId: 'team-local',
        category: LogCategory.personal,
        isSynced: false,
        isPublic: false,
      ),
    ];

    for (final log in logs) {
      await box.add(log);
    }

    expect(box.length, 3);

    // Simulasi searchLog: filter yang mengandung "Database"
    final allLogs = box.values.toList();
    final filtered = allLogs
        .where((log) => log.title.toLowerCase().contains('database'))
        .toList();

    expect(filtered.length, 1);
    expect(filtered[0].title, 'Database Design');
  });

  test('Module 3: save and filter logs from different teams (cross-team check)',
      () async {
    final box = await Hive.openBox<LogModel>(boxName);

    final log1 = LogModel(
      id: 'm3-team-001',
      title: 'Team A Log',
      description: 'Punya tim A',
      date: DateTime.now().toIso8601String(),
      authorId: 'user-a',
      teamId: 'team-a',
      category: LogCategory.other,
      isSynced: false,
      isPublic: false,
    );

    final log2 = LogModel(
      id: 'm3-team-002',
      title: 'Team B Log',
      description: 'Punya tim B',
      date: DateTime.now().toIso8601String(),
      authorId: 'user-b',
      teamId: 'team-b',
      category: LogCategory.other,
      isSynced: false,
      isPublic: false,
    );

    await box.add(log1);
    await box.add(log2);

    expect(box.length, 2);

    // Filter logs berdasarkan teamId
    final teamALogs = box.values
        .where((log) => log.teamId == 'team-a')
        .toList();
    expect(teamALogs.length, 1);
    expect(teamALogs[0].authorId, 'user-a');

    final teamBLogs = box.values
        .where((log) => log.teamId == 'team-b')
        .toList();
    expect(teamBLogs.length, 1);
    expect(teamBLogs[0].authorId, 'user-b');
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });
}