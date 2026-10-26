import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/app_state.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_widgets.dart';
import 'widgets/settings_widgets.dart';

class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});

  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ConsumerState<BackupPage> {
  final _importController = TextEditingController();
  String? _exportText;
  String? _error;
  String? _notice;
  bool _busy = false;

  @override
  void dispose() {
    _importController.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      final text = await ref.read(appStateProvider.notifier).exportJson();
      if (!mounted) return;
      setState(() {
        _exportText = text;
        _busy = false;
        _notice = '已生成备份，可复制文本或保存为 .json 文件。';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '生成备份失败：$error';
      });
    }
  }

  Future<void> _copy() async {
    final text = _exportText;
    if (text == null) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('备份文本已复制')),
    );
  }

  Future<void> _saveFile() async {
    var text = _exportText;
    if (text == null) {
      await _generate();
      if (!mounted) return;
      text = _exportText;
    }
    if (text == null) return;
    try {
      final bytes = Uint8List.fromList(utf8.encode(text));
      await FilePicker.saveFile(
        dialogTitle: '保存清欢备份',
        fileName: _fileName(),
        bytes: bytes,
        mimeType: 'application/json',
      );
      if (!mounted) return;
      setState(() {
        _notice = kIsWeb ? '已开始下载 .json 文件。' : '已保存 .json（若在对话框中取消，则不会写入）。';
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '保存文件失败：$error');
    }
  }

  Future<void> _pickFile() async {
    try {
      final file = await FilePicker.pickFile(
        dialogTitle: '选择清欢备份',
        // Android 的 DocumentsUI 对自定义扩展名支持不一致，先取任意文件再校验内容
        type: FileType.any,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 25 * 1024 * 1024) {
        throw const FormatException('文件超过 25 MB，请确认选对了文件');
      }
      var text = utf8.decode(bytes, allowMalformed: true);
      if (text.startsWith('\uFEFF')) text = text.substring(1);
      if (!mounted) return;
      setState(() {
        _importController.text = text;
        _error = null;
        _notice = '已读取 ${file.name}。确认内容后再点「导入并覆盖」。';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '读取文件失败：$error');
    }
  }

  Future<void> _import() async {
    var raw = _importController.text.trim();
    if (raw.startsWith('\uFEFF')) raw = raw.substring(1);
    if (raw.isEmpty) {
      setState(() => _error = '先粘贴备份文本，或选择一个 .json 文件。');
      return;
    }
    if (!raw.startsWith('{')) {
      setState(() => _error = '这不像一份清欢 JSON 备份。请检查文件或粘贴内容。');
      return;
    }
    final t = context.tokens;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('覆盖本地数据？'),
        content: const Text(
          '导入会先用备份内容替换当前所有档案、饮食记录、偏好和设置，且无法撤销。\n\n'
          '建议先导出当前数据，再执行导入。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: t.veryHigh,
              foregroundColor: t.surface,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('覆盖导入'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await ref.read(appStateProvider.notifier).importJson(raw);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _exportText = null;
        _importController.clear();
        _notice = '导入完成，本地数据已替换。';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '导入失败：$error';
      });
    }
  }

  String _fileName() {
    final now = DateTime.now();
    final stamp =
        '${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
    return 'plainjoy-backup-$stamp.json';
  }

  String _sizeLabel(String text) {
    final kb = text.length / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    return '${(kb / 1024).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final exportText = _exportText;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            const PageHeader(
              title: '备份与恢复',
              subtitle: '本地优先，无账号',
              showBack: true,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const InfoNote(
                    icon: Icons.shield_outlined,
                    title: '每周导出一次',
                    text: '数据只保存在本机。换机、重装或清理浏览器数据前先导出。'
                        '备份包含健康档案、饮食记录、偏好与设置，但不包含 API key；请妥善保管，不要发到公开群聊。',
                  ),
                  if (_busy) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(t.pillRadius),
                      child: LinearProgressIndicator(
                        minHeight: 3,
                        backgroundColor: t.surfaceAlt,
                        color: t.accent,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  const SectionTitle('导出', subtitle: '生成 JSON 文本，或保存为文件'),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '导出当前设备上的全部数据。文件不加密，任何拿到它的人都能读取。',
                          style: textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _busy ? null : _generate,
                          icon: const Icon(Icons.description_outlined, size: 18),
                          label: Text(exportText == null ? '生成备份' : '刷新备份'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _saveFile,
                          icon: const Icon(Icons.download_rounded, size: 18),
                          label: Text(kIsWeb ? '下载 .json 文件' : '保存 .json 文件'),
                        ),
                        if (exportText != null) ...[
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${_sizeLabel(exportText)} · 含个人数据 · 不含 API key',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: t.inkTertiary,
                                  ),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: _copy,
                                icon: const Icon(Icons.copy_rounded, size: 16),
                                label: const Text('复制'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: double.infinity,
                            constraints: const BoxConstraints(maxHeight: 220),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: t.surfaceAlt,
                              borderRadius: BorderRadius.circular(t.radiusMd),
                              border: Border.all(color: t.hairline, width: t.borderWidth),
                            ),
                            child: SingleChildScrollView(
                              child: SelectableText(
                                exportText,
                                style: textTheme.bodySmall?.copyWith(
                                  fontFamily: 'monospace',
                                  color: t.inkSecondary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '备份不包含 API key；分享前仍建议检查是否含你不想公开的记录。',
                            style: textTheme.bodySmall?.copyWith(color: t.inkTertiary),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  const SectionTitle(
                    '导入',
                    subtitle: '会覆盖当前本地数据，请先导出',
                  ),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const InfoNote(
                          icon: Icons.warning_amber_rounded,
                          text: '导入不是合并：当前档案、记录、偏好和设置会被备份内容整组替换，且无法撤销。',
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _importController,
                          minLines: 4,
                          maxLines: 8,
                          keyboardType: TextInputType.multiline,
                          decoration: const InputDecoration(
                            hintText: '在这里粘贴备份 JSON，或从文件读取…',
                          ),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _pickFile,
                          icon: const Icon(Icons.folder_open_rounded, size: 18),
                          label: const Text('选择 .json 文件'),
                        ),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: _busy ? null : _import,
                          child: const Text('导入并覆盖'),
                        ),
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    InfoNote(
                      icon: Icons.error_outline_rounded,
                      color: t.veryHigh,
                      title: '出错了',
                      text: _error!,
                    ),
                  ],
                  if (_notice != null) ...[
                    const SizedBox(height: 14),
                    InfoNote(
                      icon: Icons.check_circle_outline_rounded,
                      color: t.good,
                      title: '状态',
                      text: _notice!,
                    ),
                  ],
                  const SizedBox(height: 18),
                  Text(
                    'Web 端数据保存在浏览器本地；清理站点数据、无痕模式或换浏览器都会丢失。'
                    '原生端卸载应用同样会清空数据。',
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
