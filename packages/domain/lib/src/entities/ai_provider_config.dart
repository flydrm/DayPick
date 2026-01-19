class AiProviderConfig {
  const AiProviderConfig({
    required this.baseUrl,
    required this.model,
    this.apiKey,
    required this.updatedAt,
  });

  final String baseUrl;
  final String model;
  final String? apiKey;
  final DateTime updatedAt;

  AiProviderConfig copyWith({
    String? baseUrl,
    String? model,
    String? apiKey,
    DateTime? updatedAt,
  }) {
    return AiProviderConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? this.model,
      apiKey: apiKey ?? this.apiKey,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
