class BackupException implements Exception {
  const BackupException(this.message);

  final String message;

  @override
  String toString() => message;
}

class BackupWrongPassphraseOrCorruptedException implements Exception {
  const BackupWrongPassphraseOrCorruptedException();

  @override
  String toString() => '密码错误或文件损坏';
}

class BackupWeakPassphraseException implements Exception {
  const BackupWeakPassphraseException();

  @override
  String toString() => '密码过弱，请使用更强的 passphrase（建议 ≥12 位，含字母与数字）。';
}

class BackupCancelledException implements Exception {
  const BackupCancelledException();

  @override
  String toString() => '已取消';
}

class BackupMissingAiApiKeyException implements Exception {
  const BackupMissingAiApiKeyException();

  @override
  String toString() => '未找到 AI apiKey，请先在「AI 设置」中填写。';
}

class BackupMissingAiConfigException implements Exception {
  const BackupMissingAiConfigException();

  @override
  String toString() => 'AI 配置不完整，请先在「AI 设置」中填写 baseUrl/model。';
}

class BackupSensitiveContentDetectedException implements Exception {
  const BackupSensitiveContentDetectedException();

  @override
  String toString() => '备份失败：检测到疑似密钥（为保护隐私已中止）';
}

class BackupUnsupportedException implements Exception {
  const BackupUnsupportedException(this.message);

  final String message;

  @override
  String toString() => message;
}
