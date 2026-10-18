"""Explicit country selections; unknown locations never inherit a US number."""

COUNTRY_NAMES = {'AR': 'Argentina', 'AU': 'Australia', 'BR': 'Brazil', 'CA': 'Canada', 'CN': 'China', 'FR': 'France', 'DE': 'Germany', 'IN': 'India', 'ID': 'Indonesia', 'IT': 'Italy', 'JP': 'Japan', 'MY': 'Malaysia', 'MX': 'Mexico', 'NL': 'Netherlands', 'NZ': 'New Zealand', 'PH': 'Philippines', 'RU': 'Russia', 'SA': 'Saudi Arabia', 'SG': 'Singapore', 'ZA': 'South Africa', 'KR': 'South Korea', 'ES': 'Spain', 'SE': 'Sweden', 'CH': 'Switzerland', 'TH': 'Thailand', 'TR': 'Turkey', 'AE': 'United Arab Emirates', 'GB': 'United Kingdom', 'US': 'United States', 'VN': 'Vietnam', 'OTHER': 'Other'}


# Medical emergency numbers: national emergency services / Smartraveller country advisories.
EMERGENCY_NUMBERS = {
    "CN": "120", "JP": "119", "US": "911", "KR": "119", "IN": "112",
    "GB": "999", "FR": "112", "DE": "112", "IT": "112", "CA": "911",
    "AU": "000", "SG": "995",
}


def emergency_call(country):
    number = EMERGENCY_NUMBERS.get(str(country or "").upper())
    return f"Call {number} now." if number else "Call your local emergency number now."
