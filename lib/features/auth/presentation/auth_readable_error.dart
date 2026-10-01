String readableAuthError(Object error) {
  final message = error.toString().trim();

  if (message.startsWith('Exception: ')) {
    return message.replaceFirst('Exception: ', '');
  }

  if (message.startsWith('StateError: ')) {
    return message.replaceFirst('StateError: ', '');
  }

  return message;
}
