"""
URLChecker — phishing-heuristic URL analysis (§URL CHECKER, Phase 15).

PROTOTYPE: static structural heuristics ONLY — no live fetching, no DNS, no
threat-intelligence feeds, no ML, no sandboxing. Never claim enterprise-grade
phishing intelligence. FUTURE (master prompt): domain reputation, DNS/cert
analysis, URL sandboxing, reputation APIs, ML classifier.

Score: transparent additive weights (demo weights, not calibrated), clamped
to [0,1]. Every triggered check appears in `reasons` — explainability by
construction, same discipline as the scam rule engine.
"""
import ipaddress
import re
from typing import Dict, List
from urllib.parse import urlparse

MODEL_NAME = "heuristic_rules"

# Small prototype lists — deliberately minimal, documented, extensible.
BRANDS = ["sbi", "hdfc", "icici", "axis", "kotak", "paytm", "phonepe", "gpay",
          "googlepay", "amazon", "flipkart", "facebook", "google", "whatsapp",
          "instagram", "paypal", "apple"]
OFFICIAL_HOSTS = (".google.com", ".facebook.com", ".amazon.com", ".amazon.in",
                  ".flipkart.com", ".paytm.com", ".paypal.com", ".apple.com",
                  ".sbi.co.in", ".onlinesbi.sbi", ".hdfcbank.net", ".icicibank.com")
SUSPICIOUS_WORDS = ["otp", "kyc", "refund", "bonus", "wallet", "verify",
                    "secure", "confirm", "update-account", "signin-secure"]
SUSPICIOUS_TLDS = (".tk", ".ml", ".ga", ".cf", ".gq", ".xyz", ".top",
                   ".buzz", ".click", ".link")
SHORTENERS = {"bit.ly", "tinyurl.com", "t.co", "goo.gl", "is.gd", "cutt.ly",
              "rb.gy", "tiny.cc", "shorturl.at"}
LOGIN_WORDS = ["login", "signin", "verify", "secure", "confirm", "update"]

# (check_id, human reason, weight, predicate) — weights are DEMO weights.
def _checks(host: str, url_lower: str, path_query: str, scheme: str) -> List[tuple]:
    looks_ip = False
    try:
        ipaddress.ip_address(host)
        looks_ip = True
    except ValueError:
        looks_ip = bool(re.match(r"^\d{1,3}(\.\d{1,3}){3}$", host)) or host.startswith("0x")

    labels = host.split(".")
    long_random = any(len(lb) >= 20 and any(c.isdigit() for c in lb) and any(c.isalpha() for c in lb)
                      for lb in labels)

    brand_in_host = any(b in host for b in BRANDS) and not host.endswith(OFFICIAL_HOSTS)
    login_word = any(w in url_lower for w in LOGIN_WORDS)
    brand_in_path = any(b in path_query for b in BRANDS)

    return [
        ("ip_host", "Host is a raw IP address instead of a domain name", 0.35, looks_ip),
        ("userinfo_trick", "URL contains '@' userinfo trick (hides the real host)", 0.30,
         "@" in url_lower.split("?")[0]),
        ("brand_plus_login", "Well-known brand name combined with login/verify wording "
                             "(classic phishing pattern)", 0.30, brand_in_host and login_word),
        ("brand_in_path", "Brand name in path on an unrelated host "
                          "(IP/lookalike hosts often carry the brand in the path)", 0.15,
         brand_in_path and not host.endswith(OFFICIAL_HOSTS)),
        ("brand_host", "Well-known brand name in host (not an official domain)", 0.20, brand_in_host),
        ("shortener", "URL shortener — real destination is hidden", 0.20, host in SHORTENERS),
        ("punycode", "Punycode host (xn--) — possible homograph lookalike", 0.25, "xn--" in host),
        ("suspicious_tld", "Suspicious/cheap TLD commonly abused", 0.15,
         host.endswith(SUSPICIOUS_TLDS)),
        ("suspicious_words", "Phishing keywords in path/query (otp/kyc/refund/wallet…)", 0.15,
         any(w in path_query for w in SUSPICIOUS_WORDS)),
        ("no_https", "No HTTPS (data would travel in the clear)", 0.10, scheme != "https"),
        ("many_hyphens", "Many hyphens in host (brand-stacking pattern)", 0.10, host.count("-") >= 3),
        ("long_random_label", "Long random-looking host label", 0.10, long_random),
    ]


class URLChecker:
    """Stateless heuristics — no model to load (reported in /api/health)."""

    has_model = False

    def analyze(self, url) -> Dict:
        """Analyze one URL → {risk, reasons, model, note}. Never raises (§20)."""
        text = str(url or "").strip()
        if not text:
            return {"risk": 0.0, "reasons": [], "model": MODEL_NAME, "note": None}

        if "://" not in text:
            text = "http://" + text  # parse bare hosts like sbi-kyc-login.xyz

        try:
            parsed = urlparse(text)
        except Exception:
            return {"risk": 0.2, "reasons": ["[url_rule] URL could not be parsed"],
                    "model": MODEL_NAME, "note": None}

        host = (parsed.hostname or "").lower()
        if not host:
            return {"risk": 0.2, "reasons": ["[url_rule] URL has no parsable host"],
                    "model": MODEL_NAME, "note": None}

        url_lower = text.lower()
        path_query = (parsed.path or "") + "?" + (parsed.query or "")

        score = 0.0
        reasons: List[str] = []
        for _cid, reason, weight, triggered in _checks(host, url_lower, path_query, parsed.scheme or ""):
            if triggered:
                score += weight
                reasons.append(f"[url_rule] {reason}")

        return {
            "risk": round(min(1.0, score), 4),
            "reasons": reasons,
            "model": MODEL_NAME,
            "note": None,  # None == real heuristic run (mocks set a DEMO MODE note)
        }
