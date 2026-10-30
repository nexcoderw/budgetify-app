class ShortcutImportCredentialRoutes {
  const ShortcutImportCredentialRoutes._();

  static const instance = ShortcutImportCredentialRoutes._();
  static const String base = '/api/v1/shortcut-import-credentials';
  static const String importMessage =
      '/api/v1/financial-message-imports/shortcut';

  String rotate(String id) => '$base/$id/rotate';

  String revoke(String id) => '$base/$id';
}
