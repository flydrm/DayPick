class NoteTitle {
  NoteTitle(String value) : value = value.trim() {
    if (this.value.isEmpty) {
      throw const NoteTitleEmptyException();
    }
  }

  final String value;

  @override
  String toString() => value;
}

class NoteTitleEmptyException implements Exception {
  const NoteTitleEmptyException();
}
