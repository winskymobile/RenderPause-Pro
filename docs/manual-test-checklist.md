# RenderPause Pro MVP 手工验收清单

- [ ] 启动后仅菜单栏图标，无 Dock 图标（LSUIElement）
- [ ] 默认规则名单为空，不操作任何 App
- [ ] 添加 Notes 或 Safari，空闲阈值改为 5 秒便于测试
- [ ] 切到其他 App 并保持空闲 ≥5 秒 → 目标被隐藏
- [ ] Cmd+Tab / Dock 点回目标 → 立即出现
- [ ] 菜单「立即恢复全部」可恢复
- [ ] 「暂停监控」后不再自动隐藏
- [ ] 豁免 10 分钟后不在空闲时隐藏
- [ ] 策略改为「最小化」且未授权 AX → 日志出现 ax_not_trusted，不静默改成 hide
- [ ] 授权辅助功能后最小化策略生效
- [ ] 退出 RenderPause Pro 时，仍处于优化状态的 App 被恢复
- [ ] 无法将 RenderPause Pro 自身加入名单
