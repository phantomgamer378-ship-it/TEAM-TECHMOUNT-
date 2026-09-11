"""
Phase 15 tests — URLChecker heuristics (services/url_checker.py).

Transparent structural checks ONLY — no live fetching, ever (§URL CHECKER).

Run from backend/:  python -m pytest -v
"""
import pytest

from app.services.url_checker import URLChecker


@pytest.fixture
def checker():
    return URLChecker()


def test_ip_host_is_flagged(checker):
    out = checker.analyze("http://192.168.4.22/bank/login?otp=1")
    assert out["risk"] >= 0.5
    assert any("raw IP" in r for r in out["reasons"])


def test_brand_plus_login_is_flagged(checker):
    out = checker.analyze("http://sbi-kyc-securelogin.tk/verify")
    assert out["risk"] >= 0.5
    assert any("brand" in r.lower() for r in out["reasons"])
    assert any("TLD" in r or "tld" in r.lower() for r in out["reasons"])


def test_shortener_is_flagged(checker):
    out = checker.analyze("https://bit.ly/3xYzAbc")
    assert out["risk"] >= 0.2
    assert any("shortener" in r.lower() for r in out["reasons"])


def test_userinfo_trick_is_flagged(checker):
    out = checker.analyze("http://hdfcbank.com@evil-example.xyz/update")
    assert any("@" in r for r in out["reasons"])
    assert out["risk"] >= 0.4


def test_punycode_is_flagged(checker):
    out = checker.analyze("https://xn--pypal-4ve.com/login")
    assert any("Punycode" in r or "punycode" in r.lower() for r in out["reasons"])


def test_benign_url_scores_low(checker):
    out = checker.analyze("https://www.google.com/search?q=weather")
    assert out["risk"] <= 0.1
    assert out["model"] == "heuristic_rules"


def test_official_brand_domain_not_flagged(checker):
    """The whitelist must not flag the brand's own official domains."""
    out = checker.analyze("https://www.paypal.com/signin")
    assert not any("brand" in r.lower() for r in out["reasons"])


def test_bare_host_gets_parsed(checker):
    out = checker.analyze("sbi-kyc-login.xyz")
    assert out["risk"] >= 0.4  # no scheme → also flagged for no HTTPS


def test_empty_url_is_a_clean_zero(checker):
    assert checker.analyze("")["risk"] == 0.0


def test_deterministic(checker):
    assert checker.analyze("http://1.2.3.4/login") == checker.analyze("http://1.2.3.4/login")
