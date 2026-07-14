import 'package:flutter/material.dart';

import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

/// Fills the viewport but scrolls if content overflows (small screens/keyboard).
class _FillScroll extends StatelessWidget {
  const _FillScroll({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: c.maxHeight),
          child: IntrinsicHeight(child: child),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Welcome / onboard
// ---------------------------------------------------------------------------

class OnboardScreen extends StatelessWidget {
  const OnboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment(-.12, -1),
          end: Alignment(.12, 1),
          colors: [T.indigo, T.indigoDeep, T.indigoDark],
          stops: [0, .6, 1],
        ),
      ),
      child: SafeArea(
        child: _FillScroll(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 40, 28, 34),
            child: Column(
              children: [
                const Spacer(),
                SizedBox(
                  width: 120,
                  height: 120,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      Ripples(size: 120, color: Colors.white.withValues(alpha: .28)),
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: .4),
                              blurRadius: 30,
                              offset: const Offset(0, 12),
                              spreadRadius: -8,
                            ),
                          ],
                        ),
                        child: Center(
                          child: SizedBox(
                            width: 52,
                            height: 52,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: T.indigo.withValues(alpha: .35), width: 5),
                                  ),
                                ),
                                Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: T.indigo, width: 5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 34),
                const Text('Tandem',
                    style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -1)),
                const SizedBox(height: 10),
                Text('Tap. Split. Settle.',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: .8))),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 270),
                  child: Text(
                    'The bill-splitter and card reader that works with a single tap of your phone.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 15, height: 1.5, color: Colors.white.withValues(alpha: .62)),
                  ),
                ),
                const Spacer(),
                TButton(
                    label: 'Get started',
                    bg: Colors.white,
                    fg: T.indigoDeep,
                    onTap: app.getStarted),
                const SizedBox(height: 16),
                FooterLink(
                  prompt: 'Already have an account?',
                  action: 'Sign in',
                  light: true,
                  onTap: () => app.go(AppScreen.signin),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Choose account type
// ---------------------------------------------------------------------------

class ChooseTypeScreen extends StatelessWidget {
  const ChooseTypeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return SafeArea(
      child: _FillScroll(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 34),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BackTextButton(onTap: () => app.go(AppScreen.onboard1)),
              const SizedBox(height: 16),
              const Text('How will you use Tandem?',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: T.ink,
                      letterSpacing: -.6,
                      height: 1.15)),
              const SizedBox(height: 10),
              const Text(
                'Pick an account type to get started — you can switch modes anytime later.',
                style: TextStyle(fontSize: 15, color: T.muted, height: 1.5),
              ),
              const SizedBox(height: 28),
              _TypeCard(
                iconBg: T.indigoSoft,
                icon: const StrokeIcon(AppIcons.person, size: 26, color: T.indigo),
                title: 'Personal',
                sub: 'Split bills with friends and pay by tapping phones.',
                onTap: () => app.pickType(Mode.personal),
              ),
              const SizedBox(height: 14),
              _TypeCard(
                iconBg: T.peachBadge,
                icon: const StrokeIcon(AppIcons.store, size: 26, color: T.bizIcon),
                title: 'Business',
                sub: 'Accept tapped cards and phones from your customers.',
                onTap: () => app.pickType(Mode.business),
              ),
              const Spacer(),
              FooterLink(
                prompt: 'Already have an account?',
                action: 'Sign in',
                onTap: () => app.go(AppScreen.signin),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.iconBg,
    required this.icon,
    required this.title,
    required this.sub,
    required this.onTap,
  });

  final Color iconBg;
  final Widget icon;
  final String title;
  final String sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: T.border, width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration:
                    BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(16)),
                child: Center(child: icon),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800, color: T.ink)),
                    const SizedBox(height: 3),
                    Text(sub,
                        style: const TextStyle(fontSize: 13, color: T.muted, height: 1.4)),
                  ],
                ),
              ),
              const Text('›', style: TextStyle(fontSize: 22, color: T.faint)),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sign up
// ---------------------------------------------------------------------------

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _name = TextEditingController();
  final _business = TextEditingController();
  final _category = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _business.dispose();
    _category.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final biz = app.mode == Mode.business;
    final busy = app.authLoading;
    return SafeArea(
      child: _FillScroll(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 34),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BackTextButton(onTap: busy ? () {} : () => app.go(AppScreen.chooseType)),
              const SizedBox(height: 12),
              Pill(
                text: biz ? 'Business account' : 'Personal account',
                bg: biz ? T.peachBadge : T.indigoSoft,
                fg: biz ? T.bizBadgeFg : T.indigo,
              ),
              const SizedBox(height: 12),
              Text(
                biz ? 'Create your business account' : 'Create your personal account',
                style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: T.ink,
                    letterSpacing: -.5,
                    height: 1.15),
              ),
              if (biz) ...[
                const SizedBox(height: 20),
                LabeledField(
                    label: 'Business name',
                    hint: 'Fig & Vine Café',
                    controller: _business,
                    enabled: !busy),
                const SizedBox(height: 16),
                LabeledField(
                    label: 'Category',
                    hint: 'Café & restaurant',
                    controller: _category,
                    enabled: !busy),
              ],
              const SizedBox(height: 16),
              LabeledField(
                label: biz ? 'Owner name' : 'Full name',
                hint: biz ? 'Jordan Lee' : 'Alex Rivera',
                controller: _name,
                enabled: !busy,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              LabeledField(
                label: 'Email',
                hint: 'you@email.com',
                controller: _email,
                enabled: !busy,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              LabeledField(
                label: 'Password',
                hint: 'Create a password',
                controller: _password,
                enabled: !busy,
                obscure: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(app),
              ),
              const Spacer(),
              const SizedBox(height: 20),
              if (app.authError != null) _AuthError(app.authError!),
              _GoogleButton(
                  label: 'Sign up with Google', onTap: busy ? null : app.googleAuth),
              const SizedBox(height: 16),
              const OrDivider(),
              const SizedBox(height: 16),
              TButton(
                onTap: busy ? null : () => _submit(app),
                child: busy
                    ? const _BtnSpinner()
                    : const Text('Create account',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
              const SizedBox(height: 16),
              FooterLink(
                prompt: 'Already have an account?',
                action: 'Sign in',
                onTap: () => app.go(AppScreen.signin),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit(AppState app) {
    FocusScope.of(context).unfocus();
    app.submitSignup(
      email: _email.text,
      password: _password.text,
      fullName: _name.text,
      businessName: _business.text,
      category: _category.text,
    );
  }
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TButton(
      bg: Colors.white,
      onTap: onTap,
      border: const BorderSide(color: T.border, width: 1.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const GoogleLogo(size: 20),
          const SizedBox(width: 11),
          Text(label,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: T.ink)),
        ],
      ),
    );
  }
}

/// White spinner sized to sit inside a primary [TButton] while auth is in flight.
class _BtnSpinner extends StatelessWidget {
  const _BtnSpinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 22,
      height: 22,
      child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
    );
  }
}

/// Inline error banner shown above the auth buttons.
class _AuthError extends StatelessWidget {
  const _AuthError(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFBE9E7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF3C9C4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 18, color: Color(0xFFC0392B)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: Color(0xFFB53225),
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sign in
// ---------------------------------------------------------------------------

class SigninScreen extends StatefulWidget {
  const SigninScreen({super.key});

  @override
  State<SigninScreen> createState() => _SigninScreenState();
}

class _SigninScreenState extends State<SigninScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final busy = app.authLoading;
    return SafeArea(
      child: _FillScroll(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 34),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BackTextButton(onTap: busy ? () {} : () => app.go(AppScreen.onboard1)),
              const SizedBox(height: 16),
              const Text('Welcome back',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: T.ink,
                      letterSpacing: -.6)),
              const SizedBox(height: 10),
              const Text('Sign in to your Tandem account.',
                  style: TextStyle(fontSize: 15, color: T.muted, height: 1.5)),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(4),
                decoration:
                    BoxDecoration(color: T.segBg, borderRadius: BorderRadius.circular(14)),
                child: Row(
                  children: [
                    _SegTab(
                        label: 'Personal',
                        active: app.signinMode == Mode.personal,
                        onTap: () => app.setSigninMode(Mode.personal)),
                    _SegTab(
                        label: 'Business',
                        active: app.signinMode == Mode.business,
                        onTap: () => app.setSigninMode(Mode.business)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              LabeledField(
                label: 'Email',
                hint: 'you@email.com',
                controller: _email,
                enabled: !busy,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              LabeledField(
                label: 'Password',
                hint: 'Your password',
                controller: _password,
                enabled: !busy,
                obscure: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(app),
              ),
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerRight,
                child: Text('Forgot password?',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700, color: T.indigo)),
              ),
              const Spacer(),
              const SizedBox(height: 20),
              if (app.authError != null) _AuthError(app.authError!),
              _GoogleButton(
                  label: 'Continue with Google', onTap: busy ? null : app.googleAuth),
              const SizedBox(height: 16),
              const OrDivider(),
              const SizedBox(height: 16),
              TButton(
                onTap: busy ? null : () => _submit(app),
                child: busy
                    ? const _BtnSpinner()
                    : const Text('Sign in',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
              const SizedBox(height: 16),
              FooterLink(
                prompt: 'New to Tandem?',
                action: 'Create an account',
                onTap: () => app.go(AppScreen.chooseType),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit(AppState app) {
    FocusScope.of(context).unfocus();
    app.submitSignin(email: _email.text, password: _password.text);
  }
}

class _SegTab extends StatelessWidget {
  const _SegTab({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 40,
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: active
                ? [
                    BoxShadow(
                        color: T.ink.withValues(alpha: .14),
                        blurRadius: 3,
                        offset: const Offset(0, 1)),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: active ? T.ink : T.muted),
          ),
        ),
      ),
    );
  }
}
