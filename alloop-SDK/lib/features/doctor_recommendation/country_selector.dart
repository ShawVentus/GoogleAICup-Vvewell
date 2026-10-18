import 'package:flutter/material.dart';

const currentCountryOptions = <String, String>{
  'AR': 'Argentina',
  'AU': 'Australia',
  'BR': 'Brazil',
  'CA': 'Canada',
  'CN': 'China',
  'FR': 'France',
  'DE': 'Germany',
  'IN': 'India',
  'ID': 'Indonesia',
  'IT': 'Italy',
  'JP': 'Japan',
  'MY': 'Malaysia',
  'MX': 'Mexico',
  'NL': 'Netherlands',
  'NZ': 'New Zealand',
  'PH': 'Philippines',
  'RU': 'Russia',
  'SA': 'Saudi Arabia',
  'SG': 'Singapore',
  'ZA': 'South Africa',
  'KR': 'South Korea',
  'ES': 'Spain',
  'SE': 'Sweden',
  'CH': 'Switzerland',
  'TH': 'Thailand',
  'TR': 'Turkey',
  'AE': 'United Arab Emirates',
  'GB': 'United Kingdom',
  'US': 'United States',
  'VN': 'Vietnam',
  'OTHER': 'Other',
};

class CountrySelector extends StatelessWidget {
  const CountrySelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.compact = false,
  });

  final bool compact;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return InputDecorator(
        key: const Key('doctor-patient-country'),
        decoration: const InputDecoration(
          labelText: 'Country',
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            isDense: true,
            iconSize: 18,
            menuWidth: (MediaQuery.sizeOf(context).width - 32).clamp(
              200.0,
              360.0,
            ),
            menuMaxHeight: 320,
            style: Theme.of(context).textTheme.bodySmall,
            selectedItemBuilder: (context) => currentCountryOptions.values
                .map(
                  (name) =>
                      Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                )
                .toList(),
            items: currentCountryOptions.entries
                .map(
                  (entry) => DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
                )
                .toList(),
            onChanged: (next) {
              if (next != null) onChanged(next);
            },
          ),
        ),
      );
    }
    return DropdownButtonFormField<String>(
      key: ValueKey(value),
      initialValue: value,
      isExpanded: true,
      menuMaxHeight: 320,
      decoration: const InputDecoration(
        labelText: 'Current country',
        helperText: 'Used for emergency guidance. Change anytime.',
        helperMaxLines: 2,
      ),
      items: currentCountryOptions.entries
          .map(
            (entry) => DropdownMenuItem(
              value: entry.key,
              child: Text(entry.value, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (next) {
        if (next != null) onChanged(next);
      },
    );
  }
}
