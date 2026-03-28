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
  Role _selectedRole = Role.staff;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = widget.controller.currentUser;
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final users = widget.controller.users;
        return Scaffold(
          appBar: AppBar(title: const Text('Users & Roles')),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
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
                  }
                  if (value == 'admin') {
                    await controller.updateRole(user, Role.admin);
                  }
                  if (value == 'staff') {
                    await controller.updateRole(user, Role.staff);
                  }
                  if (value == 'viewer') {
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
