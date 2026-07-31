import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadEventBanner({required String eventId, required File file}) async {
    final ref = _storage.ref('event_banners/$eventId.jpg');
    await ref.putFile(file);
    return ref.getDownloadURL();
  }

  Future<String> uploadArchivePhoto({required String eventId, required File file, required int index}) async {
    final ref = _storage.ref('event_archives/$eventId/photo_$index.jpg');
    await ref.putFile(file);
    return ref.getDownloadURL();
  }
}
