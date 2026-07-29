import SwiftUI

struct FirstConnectionGuideView: View {
  let showControllerSettings: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      introduction

      VStack(alignment: .leading, spacing: 14) {
        guideStep(
          number: 1,
          title: "准备 Mihomo",
          description: "打开内置 Mihomo 的代理客户端；没有或不确定时先看教程。"
        )
        guideStep(
          number: 2,
          title: "开启外部控制器",
          description: "在客户端中取得本机服务地址和访问密钥。"
        )
        guideStep(
          number: 3,
          title: "连接 Mihomo Meter",
          description: "填写连接信息，成功后即可查看 Proxy 流量。"
        )
      }

      Link(destination: AppHelpLink.subscriptionConfiguration.destination) {
        Label("还没有订阅配置？了解如何获取和导入", systemImage: "link")
      }
      .font(.caption)
      .accessibilityHint("了解如何识别订阅地址并导入代理客户端")

      VStack(spacing: 8) {
        Link(destination: AppHelpLink.prepareMihomo.destination) {
          Label("查看零基础教程", systemImage: "book.closed")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .accessibilityHint("了解 Mihomo 是什么、如何获取以及怎样开启外部控制器")

        Button(action: showControllerSettings) {
          Label("我已准备好，开始连接", systemImage: "arrow.right.circle")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .accessibilityHint("打开 Mihomo 连接设置窗口")
      }
    }
  }

  private var introduction: some View {
    VStack(alignment: .leading, spacing: 6) {
      Label("第一次使用？从这里开始", systemImage: "sparkles")
        .font(.headline)

      Text(
        "Mihomo Meter 不是代理客户端，也不提供节点或订阅。"
          + "它只读取你电脑上正在运行的 Mihomo；"
          + "Clash Verge Rev 等常见客户端通常已经内置 Mihomo。"
      )
      .font(.callout)
      .foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)
    }
  }

  private func guideStep(number: Int, title: String, description: String) -> some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: "\(number).circle.fill")
        .font(.title3)
        .foregroundStyle(MihomoColorToken.brandPrimary)
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(.callout.weight(.semibold))
        Text(description)
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("第 \(number) 步，\(title)，\(description)")
  }
}
