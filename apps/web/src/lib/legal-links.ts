// Public legal documents are hosted on the publisher's site, not in this
// app -- keep these URLs in sync with the mobile app's AppConfig.
const LEGAL_BASE = "https://mustafaoner.net/kvkk-veri-isleme-gizlilik-politikalari/mk-adisyon";

export const LEGAL_LINKS = {
  terms: `${LEGAL_BASE}/kullanim-kosullari`,
  privacy: `${LEGAL_BASE}/gizlilik`,
  kvkk: `${LEGAL_BASE}/kvkk`,
} as const;
