extension StringExtension on String {
  String toTitleCase() {
    return split(' ')
        .map((word) => word.isEmpty 
            ? '' 
            : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
        .join(' ');
  }
} 