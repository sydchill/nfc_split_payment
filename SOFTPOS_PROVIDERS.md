# Real payments for Patela — SoftPOS / Tap-to-Pay provider comparison (South Africa)

Patela wants to turn a merchant's phone into the card machine: a customer taps
their **contactless card, Google Pay, or Apple Pay** on the merchant's phone.
That capability is called **SoftPOS** / **Tap to Pay on Android** / **Tap on
Phone**.

## The one hard rule

You **cannot** read a payment card yourself. Contactless card acceptance is
locked by the card networks (Visa/Mastercard) and Android to apps that are
**PCI-certified** for it (**MPoC** — Mobile Payments on COTS devices, the newer
standard that supersedes CPoC). So Patela's tap step **must** run on a certified
provider's SDK. The provider owns the certification, PCI compliance, acquiring,
and settlement; Patela embeds their SDK.

In the app this is already isolated behind `PaymentTerminal` (`mobile/lib/payments.dart`).
Today it runs on `MockTerminal`; the real integration is `HaloDotTerminal`.

## Two kinds of provider — this distinction is everything

| Kind | Examples | Can you build *your own* branded app on it? |
|------|----------|---------------------------------------------|
| **Enabler / SDK vendor** — licenses its certified SoftPOS SDK to developers | **Halo Dot** | ✅ Yes — that's their business model |
| **Closed product / competitor** — sells a finished Tap-to-Pay app to merchants | Yoco, iKhokha | ❌ No — you'd be reselling their app, not building Patela |

Because you want to build *your own* Yoco alternative, you need an **enabler**,
not a competitor's consumer product.

## Comparison

| Provider | Type | 3rd-party SoftPOS SDK? | MPoC/PCI certified | SA availability | Pricing (public) | Fit for Patela |
|----------|------|------------------------|--------------------|-----------------|------------------|----------------|
| **Halo Dot** | SoftPOS enabler / SDK vendor | ✅ White-label app **and** integrated SDK | ✅ First African-founded vendor with **PCI MPoC** (Jan 2025); Visa-Ready Tap-to-Phone | ✅ SA-founded | Not public — enterprise/negotiated | ⭐ **Top pick** — purpose-built to power apps like yours |
| **Lipa Payments** | SoftPOS enabler / SDK vendor | ✅ NFC SoftPOS SDK for your existing app; **public developer docs** | ✅ **Visa + Mastercard Full SDK *with PIN*** (one of <20 globally); EMVCo / PCI-SSC | ✅ SA (Bryanston, founded 2019) | Not public — negotiated | ⭐ **Co-top pick** — likely the fastest to start (open docs, "~11 lines" integration) |
| **Peach Payments** | Payment processor/gateway (+ Tap to Pay) | Partial — geared to their gateway/enterprise | Provider-managed | ✅ SA | Negotiated by volume; not transparent | Possible if you also want a full gateway; heavier |
| **Yoco** | Closed card-machine + Tap-to-Pay product | ❌ | Provider-managed | ✅ SA | 2.95%/txn + ~R2.50/day device use | ❌ It's the incumbent you're replacing |
| **iKhokha** | Closed card-machine + app product | ❌ | Provider-managed | ✅ SA | from ~2.75% (drops with volume) + ~R75/mo SIM | ❌ Competitor product, no dev SDK |
| **Stripe** | Global processor / Tap to Pay | SDK (other markets) | Provider-managed | ❌ **Not available in South Africa** | — | ❌ Not usable in SA |
| **Paystack** (Stripe-owned) | Processor/gateway, great dev APIs | Online payments focus, not SoftPOS Tap-to-Pay | Provider-managed | ✅ SA | Per-txn | ❌ Online gateway, not phone card-reading |

## Recommendation: **Halo Dot _or_ Lipa Payments — talk to both**

South Africa has **two** credible SoftPOS SDK enablers, and they're close enough
that commercials (not tech) should decide it.

| | **Halo Dot** | **Lipa Payments** |
|---|---|---|
| Base | SA (+ Netherlands) | SA (Bryanston, est. 2019) |
| Certification headline | **PCI MPoC** — newest unified PCI standard (first African-founded vendor, Jan 2025) + Visa Ready | **Visa + Mastercard Full SDK _with PIN_** — fewer than 20 companies globally; EMVCo / PCI-SSC evaluated |
| Developer docs | Gated behind partner onboarding | **Publicly accessible** |
| Integration claim | SDK or white-label app; "launch in days" | SDK into an existing app, "**~11 lines of code**" |
| Product range | White-label app → fully integrated SDK | SoftPOS NFC SDK for enterprises |
| Best when | You want white-label options + newest PCI standard | You want to start building **fast**, self-serve |

**Why both, not one:** they occupy the same niche (SA-native, certified,
embeddable in your own app). Contacting both costs nothing and gives you real
pricing to compare — which is the variable that actually matters, since neither
publishes rates.

**Practical lean:** for a solo developer starting now, **Lipa's public
documentation** is a real advantage — you can read the integration surface
*before* committing to a sales process. **Halo Dot's PCI MPoC** certification is
the more future-proof standard and they offer white-label if you'd rather not
build the whole app. **PIN support matters**: taps above the SA contactless floor
limit require PIN entry on-device (CVM), so confirm PIN/CVM with whichever you
pick — Lipa states Full SDK *with PIN* explicitly.

## Halo Dot's competitors (other SoftPOS SDK enablers)

These are the vendors that, like Halo Dot, **license a certified Tap-to-Pay SDK
you embed in your own app**. The catch for Patela: almost all are Europe/US/CIS
focused and **not live in South Africa** (no ZAR settlement, no local acquiring).

| Vendor | Base / main regions | Model | In South Africa? |
|--------|--------------------|-------|------------------|
| **Halo Dot** | 🇿🇦 South Africa (+ NL) | SDK + white-label, **PCI MPoC** | ✅ Native |
| **Softpay** | 🇩🇰 Nordics / Europe | SoftPOS SDK for your app | ❌ Europe-focused |
| **tapXphone** (IBA Group) | Eastern Europe / CIS (BG, EE, GR, LV, LT, RO, RS, SK…) | SoftPOS SDK | ❌ Not SA |
| **Phos** (now Ingenico) | 🇬🇧 UK / Europe | SoftPOS SDK | ❌ Not SA |
| **Ingenico SoftPOS** | Global, enterprise | SDK (heavier, enterprise) | ❌ Not marketed in SA |
| **Alcinéo** | 🇫🇷 France | Tap-to-Phone white-label/SDK | ❌ Not SA |
| **MagicCube (i-Accept)** | 🇺🇸 US | SoftPOS security + SDK | ❌ Not SA |
| **Felix Payment Systems** | 🇺🇸 US | SoftPOS SDK | ❌ Not SA |

Adjacent but **not a fit**:
- **Processor-tied Tap to Pay** (Stripe Terminal, Adyen, Viva Wallet, myPOS Glass)
  — locks you to their processing; **Stripe/Adyen Tap to Pay aren't available in
  SA** the way you'd need.
- **Network programs** (Visa *Tap to Phone*, Mastercard *Tap on Phone*) — these
  are certification frameworks that vendors like Halo Dot build **on top of**;
  you don't consume them directly.
- **Closed products** (Yoco, iKhokha) — finished apps, no third-party SDK.

## Why Halo Dot is the best option *for Patela*

It's the only choice sitting in the intersection of all four requirements:

1. **Live in South Africa** — local acquiring, **ZAR** settlement, local KYC and
   regulatory fit. The European/US SDK vendors above simply don't operate here.
2. **Enabler model** — licenses the SDK for you to build *your own* branded app
   (unlike Yoco/iKhokha, which you'd be competing against).
3. **Newest certification** — first African-founded vendor with **PCI MPoC**
   (the current standard), plus Visa-Ready Tap-to-Phone.
4. **Local support & onboarding** — same timezone, SA business/banking knowledge,
   faster path to sandbox than onboarding an offshore vendor into a new market.

In short: globally there are stronger-brand SoftPOS SDKs, but for **accepting
card taps in South Africa, in your own Flutter app, on a currently-certified
stack**, Halo Dot is the one that actually covers that combination. Confirm live
SA coverage + pricing with any vendor during onboarding — this is based on public
information.

## What onboarding involves (only you can do these)

1. **Register a business** (Pty Ltd) + a business bank account for settlement.
2. **Contact Halo Dot** (halodot.io) to onboard as a partner/merchant: KYC,
   commercial agreement (per-transaction pricing / revenue share), and access to
   their **Android Tap-to-Pay SDK + sandbox credentials**.
3. Likely an **acquiring relationship** (Halo Dot works with acquiring banks) —
   they'll guide this.
4. Provide the app for their **security/UX review** (part of the MPoC model).

## Questions to ask Halo Dot

- Do you provide a **Flutter** package/plugin, or an Android AAR we wrap in a
  platform channel? (Patela is Flutter.)
- **Sandbox** access for development before commercials are finalized?
- Per-transaction **pricing** and any monthly/SDK licensing fees?
- Which **acquirers/card schemes** are supported (Visa, Mastercard, Amex)?
- **Payout/settlement** timing and how funds reach the merchant's bank.
- Device requirements (Android version, NFC, hardware-backed keystore).
- What's needed to pass their **app security review** / go live.

## How the code is ready

- `mobile/lib/payments.dart` — `PaymentTerminal` interface, `MockTerminal` (now),
  `HaloDotTerminal` (documented integration stub).
- `AppState(terminal: ...)` selects the terminal; default is `MockTerminal`.
- The charge UI, receipt, and transaction recording already consume a
  `ChargeResult`, so wiring the real SDK is a **contained change** in
  `HaloDotTerminal.charge()` — no UI rewrite.
- **Currency:** requests are tagged `ZAR` and the UI renders `R` (rand).
- **Backend:** Patela runs its own Flask API (`backend/`) on PostgreSQL, so any
  provider webhooks/callbacks can be handled server-side in Python.
