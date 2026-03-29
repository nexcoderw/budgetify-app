import 'dart:typed_data';

class TodoUploadImage {
  const TodoUploadImage({
    required this.filename,
    required this.mimeType,
    required this.bytes,
  });

  final String filename;
  final String mimeType;
  final Uint8List bytes;
}
