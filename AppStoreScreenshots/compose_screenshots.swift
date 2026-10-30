// App Store用マーケティングスクリーンショット合成スクリプト
// 使い方: swift compose_screenshots.swift <rawDir> <outDir>
import AppKit

let args = CommandLine.arguments
let rawDir = args.count > 1 ? args[1] : "."
let outDir = args.count > 2 ? args[2] : "./final"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

struct Spec {
    let input: String
    let output: String
    let headline: String
    let subtitle: [String]
    let landscape: Bool
}

let specs: [Spec] = [
    Spec(input: "02_steps.png", output: "01_steps.png",
         headline: "成果をイッキ見",
         subtitle: ["全期間のヘルスケアデータを", "1画面に収まるチャートで表示"], landscape: false),
    Spec(input: "03_weight.png", output: "02_weight.png",
         headline: "トレンドを分析",
         subtitle: ["移動平均・回帰直線・目標ラインで", "変化の方向がひと目でわかる"], landscape: false),
    Spec(input: "04_comparison.png", output: "03_comparison.png",
         headline: "2項目の相関を見る",
         subtitle: ["歩数と体重など気になる組み合わせを", "散布図と相関係数で分析"], landscape: false),
    Spec(input: "01_home.png", output: "04_home.png",
         headline: "ヘルスケアの項目を網羅",
         subtitle: ["約100項目に対応", "よく見る項目はお気に入りへ"], landscape: false),
    Spec(input: "05_steps_landscape.png", output: "05_landscape.png",
         headline: "横向きで大きく",
         subtitle: ["iPhoneを横にすれば", "長年の記録もじっくり見渡せる"], landscape: true),
]

let topColor = NSColor(calibratedRed: 0.95, green: 0.58, blue: 0.50, alpha: 1)      // コーラル
let bottomColor = NSColor(calibratedRed: 0.93, green: 0.36, blue: 0.55, alpha: 1)   // ピンク

func font(_ size: CGFloat, weight: NSFont.Weight) -> NSFont {
    NSFont.systemFont(ofSize: size, weight: weight)
}

func draw(text: String, center: CGPoint, font: NSFont, color: NSColor) {
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
    let s = NSAttributedString(string: text, attributes: attrs)
    let size = s.size()
    s.draw(at: CGPoint(x: center.x - size.width / 2, y: center.y - size.height / 2))
}

for spec in specs {
    guard let shot = NSImage(contentsOfFile: "\(rawDir)/\(spec.input)"),
          let shotRep = shot.representations.first else {
        print("skip \(spec.input)"); continue
    }
    let shotW = CGFloat(shotRep.pixelsWide)
    let shotH = CGFloat(shotRep.pixelsHigh)

    // App Store Connectの必須スロット(Dynamic Island搭載iPhone 中型ディスプレイ)のサイズ
    let W: CGFloat = spec.landscape ? 2622 : 1206
    let H: CGFloat = spec.landscape ? 1206 : 2622
    let s: CGFloat = 1206.0 / 1320.0  // 旧レイアウト(1320基準)からの縮尺

    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H),
                                     bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                     colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0) else { continue }
    rep.size = NSSize(width: W, height: H)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // 背景グラデーション(上が明るいコーラル)
    NSGradient(starting: bottomColor, ending: topColor)?
        .draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: 90)

    let black = NSColor.black.withAlphaComponent(0.88)

    if !spec.landscape {
        // 見出し(上部・中央揃え) ※AppKitは左下原点
        draw(text: spec.headline, center: CGPoint(x: W / 2, y: H - 210 * s), font: font(128 * s, weight: .heavy), color: black)
        var y = H - 380.0 * s
        for line in spec.subtitle {
            draw(text: line, center: CGPoint(x: W / 2, y: y), font: font(64 * s, weight: .medium), color: black)
            y -= 92 * s
        }

        // 端末フレーム: 画面下端に少し見切れる配置
        let screenW: CGFloat = 1010 * s
        let screenH = screenW * shotH / shotW
        let bezel: CGFloat = 22 * s
        let screenX = (W - screenW) / 2
        let screenTopY = H - 620 * s   // 画面上端
        let screenRect = NSRect(x: screenX, y: screenTopY - screenH, width: screenW, height: screenH)
        let frameRect = screenRect.insetBy(dx: -bezel, dy: -bezel)

        // 影
        let shadow = NSShadow()
        shadow.shadowBlurRadius = 40
        shadow.shadowOffset = NSSize(width: 0, height: -14)
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
        NSGraphicsContext.current?.saveGraphicsState()
        shadow.set()
        NSColor(white: 0.12, alpha: 1).setFill()
        NSBezierPath(roundedRect: frameRect, xRadius: 150 * s, yRadius: 150 * s).fill()
        NSGraphicsContext.current?.restoreGraphicsState()

        // スクリーン(角丸クリップして描画)
        NSGraphicsContext.current?.saveGraphicsState()
        NSBezierPath(roundedRect: screenRect, xRadius: 128 * s, yRadius: 128 * s).setClip()
        shot.draw(in: screenRect, from: .zero, operation: .sourceOver, fraction: 1)
        NSGraphicsContext.current?.restoreGraphicsState()
    } else {
        // 横向き: 左にテキスト、右に端末
        let textCX = W * 0.26
        draw(text: spec.headline, center: CGPoint(x: textCX, y: H - 420 * s), font: font(120 * s, weight: .heavy), color: black)
        var y = H - 590.0 * s
        for line in spec.subtitle {
            draw(text: line, center: CGPoint(x: textCX, y: y), font: font(60 * s, weight: .medium), color: black)
            y -= 88 * s
        }

        let screenH: CGFloat = 980 * s
        let screenW = screenH * shotW / shotH   // 横長
        let bezel: CGFloat = 22 * s
        let screenX = W * 0.52
        let screenY = (H - screenH) / 2
        let screenRect = NSRect(x: screenX, y: screenY, width: screenW, height: screenH)
        let frameRect = screenRect.insetBy(dx: -bezel, dy: -bezel)

        let shadow = NSShadow()
        shadow.shadowBlurRadius = 40
        shadow.shadowOffset = NSSize(width: 0, height: -14)
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
        NSGraphicsContext.current?.saveGraphicsState()
        shadow.set()
        NSColor(white: 0.12, alpha: 1).setFill()
        NSBezierPath(roundedRect: frameRect, xRadius: 130 * s, yRadius: 130 * s).fill()
        NSGraphicsContext.current?.restoreGraphicsState()

        NSGraphicsContext.current?.saveGraphicsState()
        NSBezierPath(roundedRect: screenRect, xRadius: 110 * s, yRadius: 110 * s).setClip()
        shot.draw(in: screenRect, from: .zero, operation: .sourceOver, fraction: 1)
        NSGraphicsContext.current?.restoreGraphicsState()
    }

    NSGraphicsContext.restoreGraphicsState()
    if let data = rep.representation(using: .png, properties: [:]) {
        try? data.write(to: URL(fileURLWithPath: "\(outDir)/\(spec.output)"))
        print("wrote \(spec.output) \(Int(W))x\(Int(H))")
    }
}
