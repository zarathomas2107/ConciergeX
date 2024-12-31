class LLMResponse {
  final bool needsClarification;
  final String? clarificationMessage;
  final Map<String, dynamic>? parameters;

  LLMResponse({
    this.needsClarification = false,
    this.clarificationMessage,
    this.parameters,
  });
} 