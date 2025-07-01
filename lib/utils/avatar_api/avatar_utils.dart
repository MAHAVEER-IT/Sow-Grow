String getAvatarUrl(String name) {
  final encodedName = Uri.encodeComponent(name.replaceAll(' ', '+'));
  return "https://ui-avatars.com/api/?name=$encodedName";
}
