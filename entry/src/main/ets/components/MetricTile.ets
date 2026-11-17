@Component
export struct MetricTile {
  @Prop label: string = '';
  @Prop value: string = '';
  @Prop unit: string = '';
  @Prop note: string = '';
  build() {
    Column({ space: 6 }) {
      Text(this.label).fontSize(13).fontColor('#68776D')
      Row({ space: 3 }) {
        Text(this.value).fontSize(28).fontWeight(FontWeight.Bold).fontColor('#173F32')
        Text(this.unit).fontSize(12).fontColor('#68776D').margin({ top: 12 })
      }
      Text(this.note).fontSize(10).fontColor('#748074').maxLines(1)
    }.alignItems(HorizontalAlign.Start).padding(14).layoutWeight(1)
    .backgroundColor('#FFFFFF').borderRadius(18)
  }
}
