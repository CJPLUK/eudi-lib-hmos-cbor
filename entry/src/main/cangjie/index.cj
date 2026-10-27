package ohos_app_cangjie_entry

import kit.ArkUI.LengthProp
import kit.ArkUI.Column
import kit.ArkUI.Row
import kit.ArkUI.Text
import kit.ArkUI.Button
import kit.ArkUI.CustomView
import kit.ArkUI.CJEntry
import kit.ArkUI.loadNativeView
import kit.ArkUI.FontWeight
import kit.ArkUI.SubscriberManager
import kit.ArkUI.ObservedProperty
import kit.ArkUI.LocalStorage
import ohos.arkui.state_macro_manage.Entry
import ohos.arkui.state_macro_manage.Component
import ohos.arkui.state_macro_manage.State
// CBOR library from the eudi_cjcbor HAR (cjpm path dependency in entry/cjpm.toml)
import ohos_app_cangjie_eudi_cjcbor.cbor.*

@Entry
@Component
class EntryView {
    @State
    var message: String = "EUDI CBOR 测试面板:点按钮运行仓颉计算"

    func build() {
        Row {
            Column {
                Text("EUDI CBOR (Cangjie HAR)")
                    .fontSize(24)
                    .fontWeight(FontWeight.Bold)
                Button("编码 {\"hello\":[1,2,3]}")
                    .onClick({
                        evt => this.message = demoEncodeHex()
                    })
                Button("编解码往返自检")
                    .onClick({
                        evt => this.message = demoRoundtrip()
                    })
                Button("Canonical 排序 {10,256,-1}")
                    .onClick({
                        evt => this.message = demoCanonicalOrder()
                    })
                Button("ISO 18013-5 官方向量校验")
                    .onClick({
                        evt => this.message = demoIsoVector()
                    })
                Button("解码示例 hex")
                    .onClick({
                        evt => this.message = demoDecodeHex("a30a00190100012002")
                    })
                Text(this.message)
                    .fontSize(14)
            }.width(100.percent)
        }.height(100.percent)
    }
}
