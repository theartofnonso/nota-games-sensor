/// Internal accounts on this domain may keep `coaches.active = false` (hidden from
/// discovery) while still passing [checkCoachAccess] for the coach app.
const String kFounderCoachEmailDomainSuffix = '@ware.health';

bool isFounderCoachEmail(String email) {
  return email.trim().toLowerCase().endsWith(kFounderCoachEmailDomainSuffix);
}
