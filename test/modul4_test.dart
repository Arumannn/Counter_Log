import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logbook_app_001/features/logbook/models/log_model.dart';
import 'package:logbook_app_001/helpers/log_helper.dart';
import 'package:logbook_app_001/services/mongo_service.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;

void main() {
  const String sourceFile = "modul4_test.dart";
  final mongoService = MongoService();

  setUpAll(() async {
    await dotenv.load(fileName: ".env");
    await mongoService.connect();
  });

  tearDownAll(() async {
    await mongoService.close();
  });

  test(
    'Modul 4: koneksi MongoDB Atlas berhasil',
    () async {
      await LogHelper.writeLog(
        "--- START CONNECTION TEST ---",
        source: sourceFile,
      );

      expect(dotenv.env['MONGODB_URI'], isNotNull);

      await LogHelper.writeLog(
        "SUCCESS: Koneksi Atlas Terverifikasi",
        source: sourceFile,
        level: 2,
      );
    },
  );

  test('Modul 4: insert -> get -> update -> delete berjalan normal', () async {
    final id = ObjectId().oid;
    const teamId = 'team_modul4_test';
    const authorId = 'tester_modul4';

    final created = LogModel(
      id: id,
      title: 'M4 Insert Title',
      description: 'M4 Insert Desc',
      date: DateTime.now().toIso8601String(),
      authorId: authorId,
      teamId: teamId,
      category: LogCategory.other,
      isPublic: false,
    );

    // INSERT
    await mongoService.insertLog(created);

    // GET
    final afterInsert = await mongoService.getLogs(teamId);
    final inserted = afterInsert.where((e) => e.id == id).toList();
    expect(inserted.isNotEmpty, true);

    // UPDATE
    final updated = created.copyWith(
      title: 'M4 Updated Title',
      description: 'M4 Updated Desc',
    );
    await mongoService.updateLog(updated);

    final afterUpdate = await mongoService.getLogs(teamId);
    final updatedDoc = afterUpdate.firstWhere((e) => e.id == id);
    expect(updatedDoc.title, 'M4 Updated Title');
    expect(updatedDoc.description, 'M4 Updated Desc');

    // DELETE
    await mongoService.deleteLog(id);

    final afterDelete = await mongoService.getLogs(teamId);
    final deleted = afterDelete.where((e) => e.id == id).toList();
    expect(deleted.isEmpty, true);
  });
}