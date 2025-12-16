String capitalizeFirstLetter({required String text}) {
  return text
      .split(' ')
      .map((word) => word.isNotEmpty
          ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
          : word)
      .join(' ');
}

String capitalizeWords({required String text}) {
  List<String> words = text.split(' ');
  for (int i = 0; i < words.length; i++) {
    if (words[i].isNotEmpty) {
      words[i] =
          words[i][0].toUpperCase() + words[i].substring(1).toLowerCase();
    }
  }
  return words.join(' ');
}

String pluralize({required String word, required int count}) {
  return count == 1 ? word : '${word}s';
}

String volumeInKOrM(num number, {bool showLessThan1k = true}) {
  if (number < 1000) {
    return showLessThan1k ? "< 1K" : "$number";
  } else if (number < 1000000) {
    return '${(number / 1000).toStringAsFixed(1)}K';
  } else {
    return '${(number / 1000000).toStringAsFixed(1)}M';
  }
}

String numbersInKOrM(int number, {bool showLessThan1k = true}) {
  if (number <= 0) {
    return "0";
  } else if (number < 1000) {
    return showLessThan1k ? "1K" : "$number";
  } else if (number < 1000000) {
    return '${(number / 1000).floor()}K';
  } else {
    return '${(number / 1000000).floor()}M';
  }
}

String joinWithAnd({required List<String> items}) {
  // Check if the list is empty
  if (items.isEmpty) {
    return "";
  }

  // Check if the list has only one item
  if (items.length == 1) {
    return items.first;
  }

  // Join all elements except the last one with ', '
  String allButLast = items.sublist(0, items.length - 1).join(', ');

  // Return the string with the last item appended with 'and'
  return '$allButLast and ${items.last}';
}

String listWithAnd({required List<String> strings}) {
  if (strings.isEmpty) {
    return '';
  } else if (strings.length == 1) {
    return strings.first;
  } else {
    final allButLast = strings.sublist(0, strings.length - 1).join(', ');
    final lastItem = strings.last;
    return '$allButLast & $lastItem';
  }
}

String substringByLength({required String text, required int length}) {
  // Handle null text or non-positive length in a way that suits your needs
  if (text.isEmpty || length <= 0) {
    return '';
  }

  // Return the substring up to length if text is longer, else return text
  return text.length > length ? text.substring(0, length) : text;
}
