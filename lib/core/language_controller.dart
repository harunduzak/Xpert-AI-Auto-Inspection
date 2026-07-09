import 'package:flutter/foundation.dart';

class LanguageController {
  static final ValueNotifier<String> lang = ValueNotifier<String>('tr');

  static void setLang(String newLang) => lang.value = newLang;

  static bool get isTr => lang.value == 'tr';
}