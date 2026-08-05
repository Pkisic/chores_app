import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chores/app/theme.dart';
import 'package:chores/models/models.dart';
import 'package:chores/providers/providers.dart';
import 'package:chores/shared/widgets.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<User> _ensureAnonymousAuth() async {
    final auth = ref.read(firebaseAuthProvider);
    if (auth.currentUser != null) return auth.currentUser!;
    final cred = await auth.signInAnonymously();
    return cred.user!;
  }

  Future<void> _createHousehold() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter your display name');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = await _ensureAnonymousAuth();
      final repo = ref.read(householdRepoProvider);
      final household = await repo.createHousehold();

      await repo.addMember(
        household.id,
        Member(
          id: user.uid,
          displayName: name,
          joinedAt: Timestamp.now(),
        ),
      );

      await ref.read(householdIdProvider.notifier).set(household.id);

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _joinHousehold() async {
    final name = _nameController.text.trim();
    final code = _codeController.text.trim().toUpperCase();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter your display name');
      return;
    }
    if (code.isEmpty) {
      setState(() => _error = 'Please enter the invite code');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = await _ensureAnonymousAuth();
      final repo = ref.read(householdRepoProvider);
      final household = await repo.findByInviteCode(code);

      if (household == null) {
        setState(() => _error = 'No household found with code "$code"');
        return;
      }

      await repo.addMember(
        household.id,
        Member(
          id: user.uid,
          displayName: name,
          joinedAt: Timestamp.now(),
        ),
      );

      await ref.read(householdIdProvider.notifier).set(household.id);

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 48),

              // ── Logo / Title ───────────────────────────────
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withAlpha(80),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.home_rounded,
                    size: 40, color: Colors.white),
              ),
              const SizedBox(height: 20),
              const Text(
                'Chores',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Share the load, together.',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ),

              const SizedBox(height: 36),

              // ── Name input ─────────────────────────────────
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  hintText: 'Your display name',
                  prefixIcon: Icon(Icons.person_outline,
                      color: AppColors.textHint),
                ),
                style: const TextStyle(color: AppColors.textPrimary),
                textCapitalization: TextCapitalization.words,
              ),

              const SizedBox(height: 24),

              // ── Tab bar ────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.white,
                  unselectedLabelColor: AppColors.textSecondary,
                  dividerHeight: 0,
                  tabs: const [
                    Tab(text: 'Create household'),
                    Tab(text: 'Join household'),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Tab content ────────────────────────────────
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // CREATE
                    _buildCreateTab(),
                    // JOIN
                    _buildJoinTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreateTab() {
    return Column(
      children: [
        GlassCard(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              const Icon(Icons.add_home_outlined,
                  size: 48, color: AppColors.accent),
              const SizedBox(height: 12),
              const Text(
                'Start a new household and get an invite code to share with your partner.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _createHousehold,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Create Household',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!,
              style: const TextStyle(color: AppColors.error, fontSize: 13)),
        ],
      ],
    );
  }

  Widget _buildJoinTab() {
    return Column(
      children: [
        TextField(
          controller: _codeController,
          decoration: const InputDecoration(
            hintText: 'Enter invite code',
            prefixIcon: Icon(Icons.vpn_key_outlined,
                color: AppColors.textHint),
          ),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            letterSpacing: 4,
            fontWeight: FontWeight.w600,
          ),
          textCapitalization: TextCapitalization.characters,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _loading ? null : _joinHousehold,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _loading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : const Text(
                    'Join Household',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!,
              style: const TextStyle(color: AppColors.error, fontSize: 13)),
        ],
      ],
    );
  }
}
