# 本地化说明

## 结构

- `lib/l10n/app_zh.arb` — **模板**，中文。选它作模板是因为本应用的文案是中文写就的：
  Flutter 在某个键缺少译文时会回退到模板，所以中文作模板意味着缺失的英文会退回正确的中文，
  而不是一句无用的占位符。
- `lib/l10n/app_en.arb` — 英文。
- `lib/l10n/generated/` — `flutter gen-l10n` 生成，随代码库提交，便于像其他代码一样审阅。
  构建时自动重新生成（`pubspec.yaml` 里的 `generate: true`）。
- `lib/l10n/engine_labels.dart` — 引擎层枚举的文案。

## 为什么有些文案不在数据或引擎层

枚举项、数据层的错误、原生代码都没有 `BuildContext`，而 ARB 生成的访问器需要它。
把中文句子从这些层里抛出来，等它到了界面就只剩一个 `String`，再也回不到某个翻译键。

因此：

- **枚举只承载身份，文案由界面承载**（见 `ConnectionSort`、`RdcSessionStatus`）。
- **数据层报错误类型而非句子**（见 `ConnectionStoreError`），由界面映射成文字。

## 错误文案的处理方式

失败从来不以句子跨越层边界，只以**码**跨越，由界面选词：

- **原生层**报稳定的桥接类别码（`RDC_ERR_*`），消息是面向开发者的英文描述。
  消息本身不进界面，只在码不被识别时兜底显示。
- **界面**用 `lib/l10n/error_messages.dart` 把码映射成文案。
- **引擎层**抛 `RdcEngineException`（带 `RdcEngineError` 类型），由界面映射。

为什么不把 FreeRDP 自己的 `FREERDP_ERROR_*` 数值直接透传给界面：那些数值是库的实现细节，
一次升级就可能重新编号，而硬编码了数值的应用会**照常编译**，只是把错误的故障映射到错误的文案上。
分类放在原生侧，库的描述随消息一起带上供排查。

密码过期**单独成类**（`RDC_ERR_PASSWORD_EXPIRED`），不与「密码错误」合并：
两者给用户的建议不同——把密码过期说成密码错误，会让人反复重输一个本来就正确的密码。

## 有意未迁移的部分

| 位置 | 原因 |
|---|---|
| `lib/features/diagnostics/bridge_probe_page.dart` | 开发者自检页，不是产品界面 |
| `Resolution.label`、`RdcDesktopSize.toString` | `1920 × 1080` 是数值表示，不是文案 |

这两项是设计选择，不是缺口。

## 迁移工具

`tool/localize.dart` 保存了中文文案到 ARB 键的映射。再次改文案时走同一份映射，
不必手工重新推导。它是一次性迁移的产物，但保留下来比删除更有用。

## 新增文案

1. 在 `app_zh.arb` 和 `app_en.arb` 中同时添加键（模板缺少的键会导致生成失败或回退）。
2. `flutter gen-l10n`
3. 在代码中使用 `AppLocalizations.of(context).你的键`
4. 若在无 `context` 处使用，参照 `engine_labels.dart` 的模式，把映射放到界面层
