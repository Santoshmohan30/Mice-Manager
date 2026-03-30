import 'package:flutter/material.dart';

import '../../domain/models/role.dart';
import '../../domain/models/user_account.dart';
import '../state/auth_controller.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({
    super.key,
    required this.controller,
  });

  final AuthController controller;

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _recoveryHintController = TextEditingController();
  Role _selectedRole = Role.staff;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _recoveryHintController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final currentUser = widget.controller.currentUser;
        final users = widget.controller.users;
        final hint = currentUser?.recoveryKeyHint ?? '';
        if (_recoveryHintController.text != hint) {
          _recoveryHintController.text = hint;
        }
        return Scaffold(
          appBar: AppBar(title: const Text('Users & Roles')),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (currentUser != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'My Password',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _currentPasswordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Current password',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _newPasswordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'New password',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _confirmPasswordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Confirm new password',
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () async {
                            if (_newPasswordController.text !=
                                _confirmPasswordController.text) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('New password and confirm password must match.'),
                                ),
                              );
                              return;
                            }
                            try {
                              await widget.controller.changeOwnPassword(
                                currentPassword: _currentPasswordController.text,
                                newPassword: _newPasswordController.text,
                              );
                              _currentPasswordController.clear();
                              _newPasswordController.clear();
                              _confirmPasswordController.clear();
                              if (!context.mounted) {
                                return;
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Password updated.'),
                                ),
                              );
                            } catch (error) {
                              if (!context.mounted) {
                                return;
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(error.toString())),
                              );
                            }
                          },
                          child: const Text('Change Password'),
                        ),
                      ],
                    ),
                  ),
                ),
              if (currentUser != null && currentUser.role == Role.owner) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Owner Recovery',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Store a recovery hint only. Do not put the full recovery phrase here.',
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _recoveryHintController,
                          decoration: const InputDecoration(
                            labelText: 'Recovery hint',
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.tonal(
                          onPressed: () async {
                            try {
                              await widget.controller.updateOwnerRecoveryHint(
                                _recoveryHintController.text,
                              );
                              if (!context.mounted) {
                                return;
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Recovery hint updated.'),
                                ),
                              );
                            } catch (error) {
                              if (!context.mounted) {
                                return;
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(error.toString())),
                              );
                            }
                          },
                          child: const Text('Save Recovery Hint'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (currentUser != null &&
                  (currentUser.role == Role.owner ||
                      currentUser.role == Role.admin))
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Add Local User',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _usernameController,
                          decoration:
                              const InputDecoration(labelText: 'Username'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                              labelText: 'Temporary password'),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<Role>(
                          initialValue: _selectedRole,
                          decoration: const InputDecoration(labelText: 'Role'),
                          items: const [
                            DropdownMenuItem(
                                value: Role.admin, child: Text('Admin')),
                            DropdownMenuItem(
                                value: Role.staff, child: Text('Staff')),
                            DropdownMenuItem(
                                value: Role.viewer, child: Text('Viewer')),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _selectedRole = value);
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () async {
                            await widget.controller.createUser(
                              username: _usernameController.text,
                              password: _passwordController.text,
                              role: _selectedRole,
                            );
                            _usernameController.clear();
                            _passwordController.clear();
                          },
                          child: const Text('Create User'),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              ...users.map(
                (user) => _UserTile(
                  actor: currentUser,
                  user: user,
                  controller: widget.controller,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.actor,
    required this.user,
    required this.controller,
  });

  final UserAccount? actor;
  final UserAccount user;
  final AuthController controller;

  @override
  Widget build(BuildContext context) {
    final canManage = actor != null &&
        (actor!.role == Role.owner || actor!.role == Role.admin);
    final isOwnerProtected = user.isOwner || user.isProtected;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(user.username),
        subtitle: Text(
          '${user.role.label}${isOwnerProtected ? ' • Protected' : ''}${user.isActive ? '' : ' • Disabled'}',
        ),
        trailing: canManage
            ? PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'toggle_active') {
                    await controller.setUserActive(user, !user.isActive);
                  } else if (value == 'reset_password') {
                    final resetController = TextEditingController();
                    final newPassword = await showDialog<String>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('Reset password for ${user.username}'),
                        content: TextField(
                          controller: resetController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Temporary password',
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.of(context)
                                .pop(resetController.text.trim()),
                            child: const Text('Reset'),
                          ),
                        ],
                      ),
                    );
                    if (newPassword != null && newPassword.isNotEmpty) {
                      await controller.resetUserPassword(user, newPassword);
                    }
                  } else if (value == 'admin') {
                    await controller.updateRole(user, Role.admin);
                  } else if (value == 'staff') {
                    await controller.updateRole(user, Role.staff);
                  } else if (value == 'viewer') {
                    await controller.updateRole(user, Role.viewer);
                  }
                },
                itemBuilder: (context) => [
                  if (!isOwnerProtected) ...[
                    const PopupMenuItem(
                        value: 'admin', child: Text('Set Admin')),
                    const PopupMenuItem(
                        value: 'staff', child: Text('Set Staff')),
                    const PopupMenuItem(
                        value: 'viewer', child: Text('Set Viewer')),
                    const PopupMenuItem(
                        value: 'reset_password',
                        child: Text('Reset Password')),
                    PopupMenuItem(
                      value: 'toggle_active',
                      child:
                          Text(user.isActive ? 'Disable User' : 'Enable User'),
                    ),
                  ] else
                    const PopupMenuItem(
                      enabled: false,
                      value: 'protected',
                      child: Text('Owner protected'),
                    ),
                ],
              )
            : null,
      ),
    );
  }
}
